
begin
  require "paperclip"
rescue LoadError
  puts "Mongoid::PaperclipSidekiq requires that you install the Paperclip gem."
  exit
end
require "sidekiq/worker"
module Mongoid::PaperclipSidekiq
  
    class Queue
      
      include ::Sidekiq::Worker
      sidekiq_options :queue => :paperclip
      
      def self.enqueue(klass,field,id,*parents)
        perform_async(klass, field, id, *parents)
      end
      def perform(klass,field,id,*parents)
        if parents.empty?
          klass = klass.constantize
        else
          p = parents.shift
          parent = p[0].constantize.find(p[2])
          parents.each do |p|
            parent = parent.send(p[1].to_sym).find(p[2])
          end
          klass = parent.send(klass.to_sym)
        end
        klass.find(id).do_reprocessing_on field
      end
       
    end
    
    def has_queued_attached_file(field, options = {})


      # Include Paperclip and Paperclip::Glue for compatibility
      unless self.ancestors.include?(::Paperclip)
        include ::Paperclip
        include ::Paperclip::Glue
      end
      
      #send :include, InstanceMethods
      include InstanceMethods

      has_attached_file(field, options)
      
      # halt processing initially, but allow override for reprocess!
      self.send :"before_#{field}_post_process", :halt_processing
      
      define_method "#{field}_processing!" do 
        true
      end
      
      field "#{field}_processing", type: Boolean, default: false
      field "#{field}_processed", type: Boolean, default: false
        
      self.send :after_save do
        if self.changed.include? "#{field}_updated_at" and !self.send("#{field}_processing".to_sym)
          # add a Redis key for the application to check if we're still processing
          # we don't need it for the processing, it's just a helpful tool
          # Mongoid::PaperclipSidekiq::Redis.server.sadd(self.class.name, "#{field}:#{self.id.to_s}")

          self.send("#{field}_processing=".to_sym, true)
          self.send("#{field}_processed=".to_sym, false)
          self.save
          
          # check if the document is embedded. if so, we need that to find it later
          if self.embedded?
            parents = []
            path = self
            associations = path.reflect_on_all_associations(:embedded_in)
            until associations.empty?
              # there should only be one :embedded_in per model, correct me if I'm wrong
              association = associations.first
              path = path.send(association.name.to_sym)
              parents << [association.class_name,association.name, path.id.to_s]
              associations = path.reflect_on_all_associations(:embedded_in)

            end
            # we need the relation name, not the class name
            args = [ self.metadata.name, field, self.id.to_s] + parents.reverse
          else 
            # or just use our default params like any other Paperclip model
            args = [self.class.name, field, self.id.to_s]
          end

          # then queue up our processing
          Mongoid::PaperclipSidekiq::Queue.enqueue(*args)
        end
      end
      
      ## 
      # Define the necessary collection fields in Mongoid for Paperclip
      field(:"#{field}_file_name", :type => String)
      field(:"#{field}_content_type", :type => String)
      field(:"#{field}_file_size", :type => Integer)
      field(:"#{field}_updated_at", :type => DateTime)
    end  

    module InstanceMethods
      
      def halt_processing
        false if @is_processing.nil?  # || false
      end
            
      def do_reprocessing_on(field)
        @is_processing=true
        self.send(field.to_sym).reprocess!
        self.send("#{field}_processing=".to_sym, false)
        self.send("#{field}_processed=".to_sym, true)
        self.save
        #Mongoid::PaperclipSidekiq::Redis.server.srem(self.class.name, "#{field}:#{self.id.to_s}")
      end

    end
end
module Paperclip
  class Attachment
    def processing?
      @instance.send("#{name}_processing")
    end
    def processed?
      @instance.send("#{name}_processed")
    end
    
  end
end