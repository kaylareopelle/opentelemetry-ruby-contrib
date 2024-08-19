# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry'
require 'opentelemetry-registry'
require 'opentelemetry/instrumentation/base'
require 'opentelemetry/instrumentation/metrics_patch' if defined?(OpenTelemetry::Metrics) # maybe also add Env var check?

module OpenTelemetry
  # The instrumentation module contains functionality to register and install
  # instrumentation
  module Instrumentation
  end
end
