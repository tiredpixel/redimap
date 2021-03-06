require 'redis'
require 'json'
require 'securerandom'


module Redimap
  class RedisConn
    
    @@RESQUE_QUEUE = 'redimap'
    @@RESQUE_CLASS = 'RedimapJob'
    
    def initialize
      begin
        @redis = Redis.connect(:url => Redimap.config.redis_url)
        
        @redis.ping
      rescue Redis::CannotConnectError => e
        Redimap.logger.error { e.to_s }
        
        return
      end
      
      @KEYS = {
        :redimap_mailboxes    => "#{Redimap.config.redis_ns_redimap}:mailboxes",
        :resque_queues        => "#{Redimap.config.redis_ns_queue}:queues",
        :resque_queue_redimap => "#{Redimap.config.redis_ns_queue}:queue:#{@@RESQUE_QUEUE}",
      }.freeze
      
      if block_given?
        yield self
        
        close
      end
    end
    
    def close
      @redis.quit
    end
    
    def get_mailbox_uid(mailbox)
      @redis.hget(@KEYS[:redimap_mailboxes], mailbox).to_i # Also handles nil.
    end
    
    def set_mailbox_uid(mailbox, uid)
      @redis.hset(@KEYS[:redimap_mailboxes], mailbox, uid)
    end
    
    def queue_mailbox_uid(mailbox, uid)
      @redis.sadd(@KEYS[:resque_queues], @@RESQUE_QUEUE)
      
      @redis.rpush(@KEYS[:resque_queue_redimap], payload(mailbox, uid))
    end
    
    private
    
    def payload(mailbox, uid)
      {
        # resque
        :class => @@RESQUE_CLASS,
        :args  => [mailbox, uid],
        # sidekiq (extra)
        :queue => @@RESQUE_QUEUE,
        :retry => true,
        :jid   => SecureRandom.hex(12),
      }.to_json
    end
    
  end
end
