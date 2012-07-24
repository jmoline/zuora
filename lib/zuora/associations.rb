require 'active_support/core_ext'

module Zuora::Associations
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def has_many(klass_sym)
      prefix = "Zuora::Objects::"
      klass_name = prefix + klass_sym.to_s.classify

      instance_eval do
        define_method "#{klass_sym}" do
         klass = klass_name.constantize
         klass.where("#{self.remote_name}Id = '#{self.id}'")
        end
      end
    end

    def belongs_to(*args)
      klass_sym = args.first.to_sym
      options = args.extract_options!
      prefix = "Zuora::Objects::"
      klass_name = prefix + klass_sym.to_s.classify
      klass_name = prefix + options[:class_name] if options[:class_name]

      class_eval <<-EVAL
        define_method "#{klass_sym}=" do |obj|
          #{klass_sym}_id_will_change!
          @#{klass_sym}_id = obj.id
        end

        define_method "#{klass_sym}" do
          @#{klass_sym} ||= klass_name.constantize.where("Id = '" + send("#{klass_sym}_id") + "'").try(:first)
        end
      EVAL
    end
  end
end
