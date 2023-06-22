# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0module OpenTelemetry

module OpenTelemetry
  module Instrumentation
    module Helpers
      # Module for shared behavior among mysql libraries, like mysql2 and trilogy
      module MysqlHelper
        include OpenTelemetry::Instrumentation::Helpers::ObfuscationHelper

        QUERY_NAMES = [
          'set names',
          'select',
          'insert',
          'update',
          'delete',
          'begin',
          'commit',
          'rollback',
          'savepoint',
          'release savepoint',
          'explain',
          'drop database',
          'drop table',
          'create database',
          'create table'
        ].freeze

        QUERY_NAME_RE = Regexp.new("^(#{QUERY_NAMES.join('|')})", Regexp::IGNORECASE)

        MYSQL_COMPONENTS = %i[
          single_quotes
          double_quotes
          numeric_literals
          boolean_literals
          hexadecimal_literals
          comments
          multi_line_comments
        ].freeze

        FULL_SQL_REGEXP = Regexp.union(MYSQL_COMPONENTS.map { |component| COMPONENTS_REGEX_MAP[component] })

        private

        def obfuscate_sql(sql)
          if sql.size > config[:obfuscation_limit]
            first_match_index = sql.index(FULL_SQL_REGEXP)
            truncation_message = "SQL truncated (> #{config[:obfuscation_limit]} characters)"
            return truncation_message unless first_match_index

            truncated_sql = sql[..first_match_index - 1]
            "#{truncated_sql}...\n#{truncation_message}"
          else
            obfuscated = OpenTelemetry::Common::Utilities.utf8_encode(sql, binary: true)
            obfuscated = obfuscated.gsub(FULL_SQL_REGEXP, '?')
            obfuscated = 'Failed to obfuscate SQL query - quote characters remained after obfuscation' if detect_unmatched_pairs(obfuscated)
            obfuscated
          end
        rescue StandardError => e
          OpenTelemetry.handle_error(message: 'Failed to obfuscate SQL', exception: e)
          'OpenTelemetry error: failed to obfuscate sql'
        end

        def detect_unmatched_pairs(obfuscated)
          # We use this to check whether the query contains any quote characters
          # after obfuscation. If so, that's a good indication that the original
          # query was malformed, and so our obfuscation can't reliably find
          # literals. In such a case, we'll replace the entire query with a
          # placeholder.
          %r{'|"|\/\*|\*\/}.match(obfuscated)
        end

        def extract_statement_type(sql)
          QUERY_NAME_RE.match(sql) { |match| match[1].downcase } unless sql.nil?
        rescue StandardError => e
          OpenTelemetry.logger.debug("Error extracting sql statement type: #{e.message}")
          nil
        end
      end
    end
  end
end
