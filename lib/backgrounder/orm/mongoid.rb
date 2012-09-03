module CarrierWave
  module Backgrounder
    module ORM

      module Mongoid
        include CarrierWave::Backgrounder::ORM::Base

        def process_in_background(column, worker=::CarrierWave::Workers::ProcessAsset)
          super

          class_eval  <<-RUBY, __FILE__, __LINE__ + 1
            def trigger_#{column}_background_processing?
              process_#{column}_upload != true && #{column}_changed?
            end
          RUBY
        end

        def store_in_background(column, worker=::CarrierWave::Workers::StoreAsset)
          super

          field :"#{column}_tmp", :type => String

          class_eval  <<-RUBY, __FILE__, __LINE__ + 1
            def enqueue_#{column}_background_job
              if embedded_in = embedded? && _parent
                worker_params = [self.class.name, id.to_s, #{column}.mounted_as, embedded_in.class.name, embedded_in.id.to_s]
              else
                worker_params = [self.class.name, id.to_s, #{column}.mounted_as]
              end

              if defined? ::GirlFriday
                CARRIERWAVE_QUEUE << { :worker => #{worker}.new(*worker_params) }
              elsif defined? ::Delayed::Job
                ::Delayed::Job.enqueue #{worker}.new(*worker_params)
              elsif defined? ::Resque
                ::Resque.enqueue #{worker}, *worker_params
              elsif defined? ::Qu
                ::Qu.enqueue #{worker}, *worker_params
              elsif defined? ::Sidekiq
                ::Sidekiq::Client.enqueue #{worker}, *worker_params
              end
            end
          RUBY
        end
      end # Mongoid

    end # ORM
  end # Backgrounder
end # CarrierWave

Mongoid::Document::ClassMethods.send(:include, ::CarrierWave::Backgrounder::ORM::Mongoid)