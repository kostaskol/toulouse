module Tenancy
  class ResolutionCache
    TTL = 60.seconds

    Entry = Data.define(:tenant_attributes, :api_key_id, :last_used_at, :expires_at) do
      # An entry is shared by every thread in the process, so handing out one
      # instance would let any caller mutate another request's tenant.
      def tenant
        Tenant.instantiate(tenant_attributes)
      end

      def expired?
        expires_at <= Time.current
      end
    end

    @store = Concurrent::Map.new

    class << self
      def read(digest)
        entry = @store[digest]
        return if entry.nil?
        return entry unless entry.expired?

        @store.delete(digest)
        nil
      end

      def write(digest, api_key)
        @store[digest] = Entry.new(
          tenant_attributes: api_key.tenant.attributes_for_database.freeze,
          api_key_id: api_key.id,
          last_used_at: api_key.last_used_at,
          expires_at: Time.current + TTL
        )
      end

      # Keeps expires_at, so a digest under constant load still expires and
      # picks up a revocation within the TTL.
      def touch_last_used(digest, entry)
        touched = Tenant::ApiKey.touch_last_used(entry.api_key_id, entry.last_used_at)
        return if touched == entry.last_used_at

        @store.compute_if_present(digest) { |cached| cached.with(last_used_at: touched) }
      end

      def clear
        @store.clear
      end
    end
  end
end
