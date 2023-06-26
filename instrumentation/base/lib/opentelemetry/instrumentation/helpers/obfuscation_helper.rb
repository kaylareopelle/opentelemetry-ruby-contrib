# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0module OpenTelemetry

module OpenTelemetry
  module Instrumentation
    module Helpers
      # Module for shared obfuscation behavior among SQL libraries
      module ObfuscationHelper
        # From: https://github.com/newrelic/newrelic-ruby-agent/blob/1fca78cc7a087421ad58088d8bea72c0362bc62f/lib/new_relic/agent/database/obfuscation_helpers.rb#LL9C1-L20C10
        COMPONENTS_REGEX_MAP = {
          single_quotes: /'(?:[^']|'')*?(?:\\'.*|'(?!'))/,
          double_quotes: /"(?:[^"]|"")*?(?:\\".*|"(?!"))/,
          dollar_quotes: /(\$(?!\d)[^$]*?\$).*?(?:\1|$)/,
          uuids: /\{?(?:[0-9a-fA-F]\-*){32}\}?/,
          numeric_literals: /-?\b(?:[0-9]+\.)?[0-9]+([eE][+-]?[0-9]+)?\b/,
          boolean_literals: /\b(?:true|false|null)\b/i,
          hexadecimal_literals: /0x[0-9a-fA-F]+/,
          comments: /(?:#|--).*?(?=\r|\n|$)/i,
          multi_line_comments: %r{/\/\*(?:[^\/]|\/[^*])*?(?:\*\/|\/\*.*)/}
        }.freeze

        def obfuscate_sql(sql)
          return sql unless config[:db_statement] == :obfuscate

          if sql.size > config[:obfuscation_limit]
            first_match_index = sql.index(generated_regex)
            truncation_message = "SQL truncated (> #{config[:obfuscation_limit]} characters)"
            return truncation_message unless first_match_index

            truncated_sql = sql[..first_match_index - 1]
            return "#{truncated_sql}...\n#{truncation_message}"
          end

          # From:
          # https://github.com/newrelic/newrelic-ruby-agent/blob/9787095d4b5b2d8fcaf2fdbd964ed07c731a8b6b/lib/new_relic/agent/database/obfuscator.rb
          # https://github.com/newrelic/newrelic-ruby-agent/blob/9787095d4b5b2d8fcaf2fdbd964ed07c731a8b6b/lib/new_relic/agent/database/obfuscation_helpers.rb
          # PG UTF-8 checks need more work
          obfuscated = defined?(::PG) ? sql : OpenTelemetry::Common::Utilities.utf8_encode(sql, binary: true)
          obfuscated = obfuscated.gsub(generated_regex, '?')
          obfuscated = 'Failed to obfuscate SQL query - quote characters remained after obfuscation' if detect_unmatched_pairs(obfuscated)

          obfuscated
        rescue StandardError => e
          OpenTelemetry.handle_error(message: 'Failed to obfuscate SQL', exception: e)
          'OpenTelemetry error: failed to obfuscate sql'
        end
      end
    end
  end
end
