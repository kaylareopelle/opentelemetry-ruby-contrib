# frozen_string_literal: true

module OpenTelemetry
  module Instrumentation
    module Trilogy
      module Patches
        # Module to prepend to Trilogy for instrumentation
        module Client
          include OpenTelemetry::Instrumentation::Helpers::MysqlHelper

          def query(sql)
            tracer.in_span(
              database_span_name(sql),
              attributes: client_attributes(sql).merge!(OpenTelemetry::Instrumentation::Trilogy.attributes),
              kind: :client
            ) do
              super(sql)
            end
          end

          private

          def client_attributes(sql)
            attributes = {
              ::OpenTelemetry::SemanticConventions::Trace::DB_SYSTEM => 'mysql',
              ::OpenTelemetry::SemanticConventions::Trace::NET_PEER_NAME => connection_options.fetch(:host, 'unknown sock')
            }

            attributes[::OpenTelemetry::SemanticConventions::Trace::DB_NAME] = database_name if database_name
            attributes[::OpenTelemetry::SemanticConventions::Trace::PEER_SERVICE] = config[:peer_service] unless config[:peer_service].nil?
            attributes['db.mysql.instance.address'] = @connected_host if defined?(@connected_host)

            case config[:db_statement]
            when :obfuscate
              attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = obfuscate_sql(sql)
            when :include
              attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = sql
            end

            attributes
          end

          def database_span_name(sql) # rubocop:disable Metrics/CyclomaticComplexity
            case config[:span_name]
            when :statement_type
              extract_statement_type(sql)
            when :db_name
              database_name
            when :db_operation_and_name
              op = OpenTelemetry::Instrumentation::Trilogy.attributes['db.operation']
              name = database_name
              if op && name
                "#{op} #{name}"
              elsif op
                op
              elsif name
                name
              end
            end || 'mysql'
          end

          def database_name
            connection_options[:database]
          end

          def tracer
            Trilogy::Instrumentation.instance.tracer
          end

          def config
            Trilogy::Instrumentation.instance.config
          end
        end
      end
    end
  end
end
