# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

describe OpenTelemetry::Helpers::SqlObfuscation do
  let(:obfuscation_limit) { 2000 }
  let(:adapter) { :default }
  let(:sql) { "SELECT * from users where users.id = 1 and users.email = 'test@test.com'" }
  let(:expected) { 'SELECT * from users where users.id = ? and users.email = ?' }
  let(:obfuscate_sql) do
    OpenTelemetry::Helpers::SqlObfuscation.obfuscate_sql(
      sql,
      obfuscation_limit: obfuscation_limit,
      adapter: adapter
    )
  end

  describe '.obfuscate_sql' do
    it 'returns an obfuscated sql statement' do
      assert_equal(expected, obfuscate_sql)
    end

    describe 'when named args with defaults are not passed' do
      let(:obfuscate_sql) { OpenTelemetry::Helpers::SqlObfuscation.obfuscate_sql(sql) }

      it 'obfuscates the SQL' do
        assert_equal(expected, obfuscate_sql)
      end
    end

    describe 'when sql exceeds obfuscation_limit' do
      let(:obfuscation_limit) { 42 }
      let(:expected) { "SELECT * from users where users.id = ...\nSQL truncated (> #{obfuscation_limit} characters)" }

      it 'truncates statements beyond the obfuscation_limit after the first match' do
        assert_equal(expected, obfuscate_sql)
      end

      describe 'and sql is not encoded with UTF-8' do
        let(:sql) { "SELECT * from 😄 where users.id = 1 and users.😄 = 'test@test.com'" }
        let(:expected) { "SELECT * from  where users.id = ...\nSQL truncated (> #{obfuscation_limit} characters)" }

        it 'truncates the statements beyond the obfuscation_limit after the first match' do
          assert_equal(expected, obfuscate_sql)
        end
      end
    end

    describe 'when sql has unmatched quote' do
      let(:sql) { "SELECT * from users where users.id = 1 and users.email = 'test@test.com''" }
      it 'returns a failure message if unmatched pairs are present' do
        assert_match(/Failed to obfuscate SQL/, obfuscate_sql)
      end
    end

    describe 'when the string is not encoded with UTF-8' do
      let(:sql) { "SELECT * from users where users.id = 1 and users.email = 'test@test.com\255'" }

      describe 'when the adapter is mysql' do
        let(:adapter) { :mysql }

        it 'encodes utf8' do
          assert_equal(expected, obfuscate_sql)
        end
      end

      describe 'when the adapter is postgres' do
        let(:adapter) { :postgres }

        it 'encodes utf8' do
          assert_equal(expected, obfuscate_sql)
        end
      end

      describe 'when the sql statement has an emoji' do
        let(:sql) { "SELECT * from users where users.id = 1 and users.email = 'test@😄.com'" }

        it 'encodes utf8' do
          assert_equal(expected, obfuscate_sql)
        end
      end
    end
  end
end
