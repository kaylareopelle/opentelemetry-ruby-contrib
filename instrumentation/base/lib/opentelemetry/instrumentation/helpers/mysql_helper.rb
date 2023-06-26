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

        def generated_regex
          @generated_regex ||= Regexp.union(MYSQL_COMPONENTS.map { |component| COMPONENTS_REGEX_MAP[component] })
        end

        private


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
