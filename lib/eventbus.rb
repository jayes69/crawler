class Eventbus
  
  def initialize
    puts "Eventbus initialize"
    @subscribers = {}
    @counter = 0
  end

  def subscribe(&subscriber)
    puts "Eventbus subscribe"
    counter = @counter+=1
    @subscribers[counter] = subscriber
    counter
  end

  def unsubscribe(id)
    puts "Eventbus unsubscribe"
    @subscribers.delete(id)
  end

  def publish(event)
    puts "Eventbus publish"
    @subscribers.values.each do |subscriber|
      subscriber.call(event)
    end
  end

end