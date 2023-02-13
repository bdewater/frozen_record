# frozen_string_literal: true

module FrozenRecord
  module Compact
    extend ActiveSupport::Concern

    module ClassMethods
      def load_records(force: false)
        if force || (auto_reloading && file_changed?)
          @records = nil
          undefine_attribute_methods
        end

        @records ||= begin
          records = backend.load(file_path)
          if attribute_deserializers.any? || default_attributes
            records = records.map { |r| assign_defaults!(deserialize_attributes!(r.dup)).freeze }.freeze
          end
          @attributes = list_attributes(records).freeze
          build_attributes_cache
          define_attribute_methods(@attributes.to_a)
          records = FrozenRecord.ignore_max_records_scan { records.map { |r| load(r) }.freeze }
          index_definitions.values.each { |index| index.build(records) }
          records
        end
      end

      def define_method_attribute(attr, **)
        generated_attribute_methods.attr_reader(attr)
      end

      attr_reader :_attributes_cache

      private

      def build_attributes_cache
        @_attributes_cache = @attributes.each_with_object({}) do |attr, cache|
          var = :"@#{attr}"
          cache[attr.to_s] = var
          cache[attr.to_sym] = var
        end
      end
    end

    def initialize(attrs = {})
      self.attributes = attrs
    end

    def attributes
      self.class.attributes.each_with_object({}) do |attr, hash|
        hash[attr] = self[attr]
      end
    end

    def [](attr)
      if var = self.class._attributes_cache[attr]
        instance_variable_get(var)
      end
    end

    private

    def attributes=(attributes)
      self.class.attributes.each do |attr|
        instance_variable_set(self.class._attributes_cache[attr], attributes[attr])
      end
    end

    def attribute?(attribute_name)
      val = self[attribute_name]
      !Base::FALSY_VALUES.include?(val) && val.present?
    end
  end
end
