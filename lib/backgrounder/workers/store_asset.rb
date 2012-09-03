# encoding: utf-8
module CarrierWave
  module Workers

    class StoreAsset < Struct.new(:klass, :id, :column, :parent_class, :parent_id)
      include ::Sidekiq::Worker if defined?(::Sidekiq)
      @queue = :store_asset

      def self.perform(*args)
        new(*args).perform
      end

      def perform(*args)
        set_args(*args) unless args.empty?

        resource = klass.is_a?(String) ? klass.constantize : klass
        if parent_class
          # This is needed for embeded resources in mongoid
          parent_resource = parent_class.is_a?(String) ? parent_class.constantize : parent_class
          parent_record = parent_resource.find(parent_id)
          resource = parent_record.send(klass.downcase.pluralize)
        end
        record = resource.find id

        if tmp = record.send(:"#{column}_tmp")
          asset = record.send(:"#{column}")
          cache_dir  = [asset.root, asset.cache_dir].join("/")
          cache_path = [cache_dir, tmp].join("/")
          tmp_dir = [cache_dir, tmp.split("/")[0]].join("/")
          record.send :"process_#{column}_upload=", true
          record.send :"#{column}_tmp=", nil
          File.open(cache_path) { |f| record.send :"#{column}=", f }
          if record.save!
            FileUtils.rm_r(tmp_dir, :force => true)
          end
        end
      end

      def set_args(klass, id, column, parent_class = nil, parent_id = nil)
        self.klass, self.id, self.column, self.parent_class, self.parent_id = klass, id, column, parent_class, parent_id
      end

    end # StoreAsset

  end # Workers
end # Backgrounder
