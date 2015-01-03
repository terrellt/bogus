module Bogus
  class Interaction < Struct.new(:method, :args, :return_value, :error, :has_result)
    attr_accessor :arguments

    def self.same?(opts = {})
      InteractionComparator.new(opts).same?
    end

    def initialize(method, args, &block)
      self.method = method
      self.args = args

      if block_given?
        evaluate_return_value(block)
        self.has_result = true
      end
    end

    private

    def evaluate_return_value(block)
      self.return_value = block.call
    rescue => e
      self.error = e.class
    end

    class InteractionComparator
      attr_reader :recorded, :stubbed

      def initialize(opts = {})
        @recorded = opts.fetch(:recorded)
        @stubbed = opts.fetch(:stubbed)
      end

      def same?
        return false unless recorded.method == stubbed.method
        return false unless same_result?
        same_args?
      end

      private

      def same_args?
        ArgumentComparator.new(recorded: recorded.args, stubbed: stubbed.args).same?
      end

      def same_result?
        return true unless recorded.has_result && stubbed.has_result
        return same_entities? if recorded.return_value.kind_of?(Bogus::Fake) || stubbed.return_value.kind_of?(Bogus::Fake)
        recorded.return_value == stubbed.return_value && recorded.error == stubbed.error
      end

      def same_entities?
        return false unless recorded.return_value.class.respond_to?(:__copied_class__, true) && stubbed.return_value.class.respond_to?(:__copied_class__, true)
        return false unless recorded.return_value.class.__copied_class__ == stubbed.return_value.class.__copied_class__
        recorded_stubs = recorded.return_value.__shadow__.instance_variable_get(:@stubs)
        stubbed_stubs = stubbed.return_value.__shadow__.instance_variable_get(:@stubs)
        recorded_stubs.each do |recorded_stub|
          found = false
          stubbed_stubs.each do |stubbed_stub|
            if Interaction.same?({:recorded => recorded_stub[0], :stubbed => stubbed_stub[0]})
              found = true if recorded_stub[1].call == stubbed_stub[1].call
              break
            end
          end
          return false unless found
        end
        return true
      end
    end

    class ArgumentComparator
      attr_reader :recorded, :stubbed

      def initialize(opts = {})
        @recorded = opts.fetch(:recorded)
        @stubbed = opts.fetch(:stubbed)
      end

      def same?
        return true if with_matcher_args?
        return false if stubbed.length != recorded_without_defaults.length
        stubbed.each_with_index do |stubbed_arg, i|
          return false unless compare_arguments(recorded_without_defaults[i], stubbed_arg)
        end
        true
      end

      private

      def compare_arguments(recorded_arg, stubbed_arg)
        return compare_entities(recorded_arg, stubbed_arg) if recorded_arg.kind_of?(Bogus::Fake) && stubbed_arg.kind_of?(Bogus::Fake)
        stubbed_arg == recorded_arg
      end

      def compare_entities(recorded_arg, stubbed_arg)
        return false unless recorded_arg.class.__copied_class__ == stubbed_arg.class.__copied_class__
        recorded_stubs = recorded_arg.__shadow__.instance_variable_get(:@stubs)
        stubbed_stubs = stubbed_arg.__shadow__.instance_variable_get(:@stubs)
        recorded_stubs.each do |recorded_stub|
          found = false
          stubbed_stubs.each do |stubbed_stub|
            if Interaction.same?({:recorded => recorded_stub[0], :stubbed => stubbed_stub[0]})
              found = true if recorded_stub[1].call == stubbed_stub[1].call
              break
            end
          end
          return false unless found
        end
        return true
      end

      def recorded_without_defaults
        without_defaults = recorded.reject{|v| DefaultValue == v}
        remove_default_keywords(without_defaults)
      end

      def remove_default_keywords(recorded)
        return recorded unless recorded_has_keyword?
        positional = recorded[0...-1]
        keyword = recorded.last
        without_defaults = keyword.reject{|_, v| DefaultValue == v}
        return positional if without_defaults.empty?
        positional + [without_defaults]
      end

      def with_matcher_args?
        WithArguments.matches?(stubbed: stubbed, recorded: recorded_without_defaults)
      end

      def recorded_has_keyword?
        last_recorded = recorded.last
        return false unless last_recorded.is_a?(Hash)
        last_recorded.values.any? { |v| DefaultValue == v }
      end
    end
  end
end
