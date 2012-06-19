class Bogus::RecordingProxy < BasicObject
  def initialize(instance, fake_name, interactions_repository)
    @instance = instance
    @fake_name = fake_name
    @interactions_repository = interactions_repository
  end

  def method_missing(name, *args, &block)
    @interactions_repository.record(@fake_name, name, *args, &block)
    @instance.__send__(name, *args, &block)
  end

  def respond_to?(name)
    @instance.respond_to?(name)
  end
end

