# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Instrumentation
    module Trilogy
      module Patches
        # Module to prepend to Trilogy for instrumentation
        module Client
          def query(sql)
            tracer.in_span(
              OpenTelemetry::Helpers::MySQL.database_span_name(
                sql,
                OpenTelemetry::Instrumentation::Trilogy.attributes[
                  OpenTelemetry::SemanticConventions::Trace::DB_OPERATION
                ],
                database_name,
                config
              ),
              attributes: client_attributes(sql).merge!(
                OpenTelemetry::Instrumentation::Trilogy.attributes
              ),
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
            attributes[::OpenTelemetry::SemanticConventions::Trace::DB_USER] = database_user if database_user
            attributes[::OpenTelemetry::SemanticConventions::Trace::PEER_SERVICE] = config[:peer_service] unless config[:peer_service].nil?
            attributes['db.mysql.instance.address'] = @connected_host if defined?(@connected_host)

            case config[:db_statement]
            when :obfuscate
              attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] =
                OpenTelemetry::Helpers::SqlObfuscation.obfuscate_sql(sql, obfuscation_limit: config[:obfuscation_limit], adapter: :mysql)
            when :include
              attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = sql
            end

            attributes
          end

          def database_name
            connection_options[:database]
          end

          def database_user
            connection_options[:username]
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
