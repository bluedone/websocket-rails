require 'websocket_rails/data_store'

module WebsocketRails
  # Provides controller helper methods for developing a WebsocketRails controller. Action methods
  # defined on a WebsocketRails controller can be mapped to events using the {Events} class.
  # This class should be sub classed in a user's application, similar to the ApplicationController
  # in a Rails application. You can create your WebsocketRails controllers in your standard Rails
  # controllers directory.
  #
  # == Example WebsocketRails controller
  #   class ChatController < WebsocketRails::BaseController
  #     # Can be mapped to the :client_connected event in the events.rb file.
  #     def new_user
  #       send_message :new_message, {:message => 'Welcome to the Chat Room!'}
  #     end
  #   end
  #
  # It is best to use the provided {DataStore} to temporarily persist data for each client between
  # events. Read more about it in the {DataStore} documentation.
  class BaseController
    
    # Add observers to specific events or the controller in general. This functionality is similar
    # to the Rails before_filter methods. Observers are stored as Proc objects and have access
    # to the current controller environment.
    #
    # Observing all events sent to a controller:
    #   class ChatController < WebsocketRails::BaseController
    #     observe {
    #       if data_store.each_user.count > 0
    #         puts 'a user has joined'
    #       end
    #     }
    #   end
    # Observing a single event that occurrs:
    #   observe(:new_message) {
    #     puts 'new_message has fired!'
    #   }
    def self.observe(event = nil, &block)
      if event
        @@observers[event] << block
      else
        @@observers[:general] << block
      end
    end
    
    # Stores the observer Procs for the current controller. See {observe} for details.
    @@observers = Hash.new {|h,k| h[k] = Array.new}
    
    def initialize
      @data_store = DataStore.new(self)
    end
    
    # Provides direct access to the Faye::WebSocket connection object for the client that
    # initiated the event that is currently being executed.
    def connection
      @_connection
    end
    
    # The numerical ID for the client connection that initiated the event. The ID is unique
    # for each currently active connection but can not be used to associate a client between
    # multiple connection attempts. 
    def client_id
      connection.object_id
    end
    
    # The current message that was passed from the client when the event was initiated. The
    # message is typically a standard ruby Hash object. See the README for more information.
    def message
      @_message
    end
    
    # Sends a message to the client that initiated the current event being executed. Messages
    # are serialized as JSON into a two element Array where the first element is the event
    # and the second element is the message that was passed, typically a Hash.
    #   message_hash = {:message => 'new message for the client'}
    #   send_message :new_message, message_hash
    #   # Will arrive on the client as JSON string like the following:
    #   # ['new_message',{message: 'new message for the client'}]
    def send_message(event, message)
      @_dispatcher.send_message event.to_s, message, connection if @_dispatcher.respond_to?(:send_message)
    end
    
    # Broadcasts a message to all connected clients. See {#send_message} for message passing details.
    def broadcast_message(event, message)
      @_dispatcher.broadcast_message event.to_s, message if @_dispatcher.respond_to?(:broadcast_message)
    end
    
    # Provides access to the {DataStore} for the current controller. The {DataStore} provides convenience
    # methods for keeping track of data associated with active connections. See it's documentation for
    # more information.
    def data_store
      @data_store
    end
    
    private
    
    # Executes the observers that have been defined for this controller. General observers are executed
    # first and event specific observers are executed last. Each will be executed in the order that
    # they have been defined. This method is executed by the {Dispatcher}.
    def execute_observers(event)
      @@observers[:general].each do |observer|
        instance_eval( &observer )
      end
      @@observers[event].each do |observer|
        instance_eval( &observer )
      end
    end
    
  end
end