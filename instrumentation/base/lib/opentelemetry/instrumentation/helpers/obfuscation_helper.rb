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
      end
    end
  end
end
