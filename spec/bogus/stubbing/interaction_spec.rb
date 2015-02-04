require 'spec_helper'

module Bogus
  describe Interaction do
    class SomeError < StandardError; end
    class SomeClass; def result; end; def bla; end; end;

    same = [
      [[:foo, [:bar], "value"], [:foo, [:bar], "value"]],
      [[:foo, [:bar, DefaultValue], "value"], [:foo, [:bar], "value"]],
      [[:foo, [:bar, {foo: DefaultValue}], "value"], [:foo, [:bar], "value"]],
      [[:foo, [:bar, {foo: DefaultValue, bar: 1}], "value"], [:foo, [:bar, {bar: 1}], "value"]],
      [[:foo, [DefaultValue, {foo: DefaultValue}], "value"], [:foo, [], "value"]],
      [[:foo, [:bar]], [:foo, [:bar], "value"]],
      [[:foo, [:bar], "value"], [:foo, [:bar]]],
      [[:foo, [:bar]], [:foo, [:bar]]],
      [[:foo, [:bar]], [:foo, [AnyArgs]]],
      [[:foo, [:bar], "same value"], [:foo, [AnyArgs], "same value"]],
      [[:foo, [:bar, :baz]], [:foo, [:bar, Anything]]],
      [[:foo, [1], "same value"], [:foo, [WithArguments.new{|n| n.odd?}], "same value"]],
      [[:banana, [],Bogus.fake_for(:some_class, :result => 1){SomeClass}], [:banana, [],Bogus.fake_for(:some_class, :result => 1){SomeClass}]],
      [[:foo, [1]], [:foo, [SameClass.new(Integer)]]]
    ]

    different = [
      [[:foo, [:bar], "value"], [:foo, [:bar], "value2"]],
      [[:foo, [:bar, :baz], "value"], [:foo, [:baz, Anything], "value"]],
      [[:foo, [nil, {foo: DefaultValue}], "value"], [:foo, [], "value"]],
      [[:foo, [DefaultValue, {foo: DefaultValue}], "value"], [:foo, [{}], "value"]],
      [[:foo, [:bar], "value"], [:baz, [:bar], "value"]],
      [[:foo, [{}], "value"], [:foo, [], "value"]],
      [[:foo, [:baz], "value"], [:foo, [:bar], "value"]],
      [[:foo, [DefaultValue, :baz], "value"], [:foo, [:bar, :bar], "value"]],
      [[:foo, [:bar, {foo: DefaultValue, bar: 1}], "value"], [:foo, [:bar, {bar: 2}], "value"]],
      [[:foo, [:bar]], [:bar, [AnyArgs]]],
      [[:foo, [:bar], "some value"], [:foo, [AnyArgs], "other value"]],
      [[:foo, [:bar]], [:foo, [:baz]]],
      [[:baz, [:bar]], [:foo, [:bar]]],
      [[:foo, [2], "same value"], [:foo, [WithArguments.new{|n| n.odd?}], "same value"]],
      [[:banana, [],Bogus.fake_for(:some_class, :result => 1){SomeClass}], [:banana, [],Bogus.fake_for(:some_class, :result => 2){SomeClass}]],
      [[:foo, [1]], [:foo, [SameClass.new(Symbol)]]]
    ]

    def create_interaction(interaction)
      method_name, args, return_value = interaction
      if return_value
        Interaction.new(method_name, args) { return_value }
      else
        Interaction.new(method_name, args)
      end
    end

    same.each do |first_interaction, second_interaction|
      it "returns true for #{first_interaction.inspect} and #{second_interaction.inspect}" do
        first = create_interaction(first_interaction)
        second = create_interaction(second_interaction)

        expect(Interaction.same?(recorded: first, stubbed: second)).to be(true)
      end
    end

    different.each do |first_interaction, second_interaction|
      it "returns false for #{first_interaction.inspect} and #{second_interaction.inspect}" do
        first = create_interaction(first_interaction)
        second = create_interaction(second_interaction)

        expect(Interaction.same?(recorded: first, stubbed: second)).to be(false)
      end
    end

    it "differs exceptions from empty return values" do
      first = Interaction.new(:foo, [:bar]) { raise SomeError }
      second = Interaction.new(:foo, [:bar]) { nil }

      expect(Interaction.same?(recorded: first, stubbed: second)).to be(false)
    end

    it "differs raised exceptions from ones just returned from the block" do
      first = Interaction.new(:foo, [:bar]) { raise SomeError }
      second = Interaction.new(:foo, [:bar]) { SomeError }

      expect(Interaction.same?(recorded: first, stubbed: second)).to be(false)
    end

    it "considers exceptions of the same type as equal" do
      first = Interaction.new(:foo, [:bar]) { raise SomeError }
      second = Interaction.new(:foo, [:bar]) { raise SomeError }

      expect(Interaction.same?(recorded: first, stubbed: second)).to be(true)
    end

    context 'when comparing arguments with custom #== implementations' do
      Dev = Struct.new(:login) do
        def ==(other)
          login == other.login
        end
      end

      it "considers two interactions == when the arguments are ==" do
        first = Interaction.new(:with, [Dev.new(:psyho)])
        second = Interaction.new(:with, [Dev.new(:psyho)])

        expect(Interaction.same?(recorded: first, stubbed: second)).to be(true)
      end

      it "considers two interactions != when the arguments are !=" do
        first = Interaction.new(:with, [Dev.new(:wrozka)])
        second = Interaction.new(:with, [Dev.new(:yundt)])

        expect(Interaction.same?(recorded: first, stubbed: second)).to be(false)
      end
    end
  end
end
