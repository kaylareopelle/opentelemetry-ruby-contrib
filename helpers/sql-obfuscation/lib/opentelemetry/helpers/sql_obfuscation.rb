# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0module OpenTelemetry

require 'opentelemetry-common'

module OpenTelemetry
  module Helpers
    #
    # This class contains SQL obfuscation behavior to share with
    # instrumentation for specific database adapters.
    # The class uses code from: https://github.com/newrelic/newrelic-ruby-agent/blob/1fca78cc7a087421ad58088d8bea72c0362bc62f/lib/new_relic/agent/database/obfuscation_helpers.rb
    #
    # To use this in your instrumentation, the `Instrumentation` class for
    # your gem must contain configuration options for:
    #  * `:db_statement`
    #    Example:
    #    `option :db_statement, default: :include, validate: %I[omit include obfuscate]`
    #  * `:obfuscation_limit`
    #    Example:
    #    `option :obfuscation_limit, default: 2000, validate: :integer`
    #
    # If you want to add support for a new adapter, update the following
    # constants to include keys for your adapter:
    #  * DIALECT_COMPONENTS
    #  * CLEANUP_REGEX
    # You must also add a new constant that uses `generate_regex` with your
    # adapter's dialect components that is named like
    # `<ADAPTER>_COMPONENTS_REGEX`, such as: `MYSQL_COMPONENTS_REGEX`.
    #
    # @api public
    class SqlObfuscation
      # From: https://github.com/newrelic/newrelic-ruby-agent/blob/1fca78cc7a087421ad58088d8bea72c0362bc62f/lib/new_relic/agent/database/obfuscation_helpers.rb
      COMPONENTS_REGEX_MAP = {
        single_quotes: /'(?:[^']|'')*?(?:\\'.*|'(?!'))/,
        double_quotes: /"(?:[^"]|"")*?(?:\\".*|"(?!"))/,
        dollar_quotes: /(\$(?!\d)[^$]*?\$).*?(?:\1|$)/,
        uuids: /\{?(?:[0-9a-fA-F]\-*){32}\}?/,
        numeric_literals: /-?\b(?:[0-9]+\.)?[0-9]+([eE][+-]?[0-9]+)?\b/,
        boolean_literals: /\b(?:true|false|null)\b/i,
        hexadecimal_literals: /0x[0-9a-fA-F]+/,
        comments: /(?:#|--).*?(?=\r|\n|$)/i,
        multi_line_comments: %r{\/\*(?:[^\/]|\/[^*])*?(?:\*\/|\/\*.*)}
      }.freeze

      DIALECT_COMPONENTS = {
        default: COMPONENTS_REGEX_MAP.keys,
        mysql: %i[
          single_quotes
          double_quotes
          numeric_literals
          boolean_literals
          hexadecimal_literals
          comments
          multi_line_comments
        ],
        postgres: %i[
          single_quotes
          dollar_quotes
          uuids
          numeric_literals
          boolean_literals
          comments
          multi_line_comments
        ]
      }.freeze

      PLACEHOLDER = '?'
      UNMATCHED_PAIRS_FAILURE_MESSAGE = 'Failed to obfuscate SQL query - quote characters remained after obfuscation'
      OBFUSCATION_FAILURE_MESSAGE = 'Failed to obfuscate SQL'

      # We use these to check whether the query contains any quote characters
      # after obfuscation. If so, that's a good indication that the original
      # query was malformed, and so our obfuscation can't reliably find
      # literals. In such a case, we'll replace the entire query with a
      # placeholder.
      CLEANUP_REGEX = {
        default: %r{'|"|\/\*|\*\/},
        mysql: %r{'|"|\/\*|\*\/},
        postgres: %r{'|\/\*|\*\/|\$(?!\?)}
      }.freeze

      # @api private
      def self.generate_regex(dialect)
        components = DIALECT_COMPONENTS[dialect]
        Regexp.union(components.map { |component| COMPONENTS_REGEX_MAP[component] })
      end

      DEFAULT_COMPONENTS_REGEX = generate_regex(:default)
      MYSQL_COMPONENTS_REGEX = generate_regex(:mysql)
      POSTGRES_COMPONENTS_REGEX = generate_regex(:postgres)

      # This is a SQL obfuscation utility intended for use in database adapter instrumentation.
      #
      # @param sql [String] The SQL to obfuscate.
      # @param obfuscation_limit [optional Integer] The maximum length of an obfuscated sql statement.
      # @param adapter [optional Symbol] the type of database adapter calling the method. `:default`, `:mysql` and `:postgres` are supported.
      # @return [String] The SQL query string where the values are replaced with "?". When the sql statement exceeds the obufscation limit
      #  the first matched pair from the SQL statement will be returned, with an appended truncation message. If trunaction is unsuccessful,
      #  a string describing the error will be returned.
      #
      # @api public
      def self.obfuscate_sql(sql, obfuscation_limit: 2000, adapter: :default)
        regex = case adapter
                when :mysql
                  MYSQL_COMPONENTS_REGEX
                when :postgres
                  POSTGRES_COMPONENTS_REGEX
                else
                  DEFAULT_COMPONENTS_REGEX
                end

        # Original MySQL UTF-8 Encoding Fixes:
        # https://github.com/open-telemetry/opentelemetry-ruby-contrib/pull/160
        # https://github.com/open-telemetry/opentelemetry-ruby-contrib/pull/345
        sql = OpenTelemetry::Common::Utilities.utf8_encode(sql, binary: true)
        return truncate_statement(sql, regex, obfuscation_limit) if sql.size > obfuscation_limit

        sql = sql.gsub(regex, PLACEHOLDER)
        return UNMATCHED_PAIRS_FAILURE_MESSAGE if CLEANUP_REGEX[adapter].match(sql)

        sql
      rescue StandardError => e
        OpenTelemetry.handle_error(message: OBFUSCATION_FAILURE_MESSAGE, exception: e)
        "OpenTelemetry error: #{OBFUSCATION_FAILURE_MESSAGE}"
      end

      # @api private
      def self.truncate_statement(sql, regex, limit)
        first_match_index = sql.index(regex)
        truncation_message = "SQL truncated (> #{limit} characters)"
        return truncation_message unless first_match_index

        truncated_sql = sql[..first_match_index - 1]
        "#{truncated_sql}...\n#{truncation_message}"
      end
    end
  end
end
