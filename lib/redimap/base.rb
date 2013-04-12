module Redimap
  
  def self.config
    @config ||= Redimap::Config.new
  end
  
  def self.configure
    yield @config
  end
  
  def self.queue_new_mailboxes_uids
    Redimap::ImapConn.new do |imap|
      Redimap::RedisConn.new do |redis|
        Redimap.config.imap_mailboxes.each do |mailbox|
          last_seen_uid = redis.get_mailbox_uid(mailbox)
          
          unseen_uids = imap.read_mailbox(mailbox, last_seen_uid)
          
          unseen_uids.each do |uid|
            redis.queue_mailbox_uid(mailbox, uid)
            
            redis.set_mailbox_uid(mailbox, uid)
          end
        end
      end
    end
  end
  
end