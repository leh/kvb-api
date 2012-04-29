require 'arrivals'

class Vehicle

  attr_accessor :line, :destination, :direction, :position, :speed

  def self.at_station(station)
    arrivals = Arrivals.new(station.kvb_id).import.trains

    arrivals.map do |arrival|
      line = Line.find_by_number(arrival[:line])
      Rails.logger.debug { "Line: #{line.number} => #{arrival[:destination]}" }
      if destination = Station.with_name_or_alias(arrival[:destination])
        direction = station.direction(line, destination) # :up, :down, nil
        Vehicle.new(line, direction, destination, station, arrival[:arrival])
      end
    end.compact
  end

  def kind
    line.kind
  end

  def initialize(line, direction, destination, station, travel_time_to_station)
    self.line = line
    self.direction = direction
    self.destination = destination

    @station = station
    @travel_time_to_station = travel_time_to_station
  end

  def id
    @id ||= nil
  end

  def arrival_time_at_destination
    @arrival_time_at_destination ||= begin
      route = Line.cached_routes[line.number]

      state = :delete
      remaining_route = route.delete_if do |station_kvb_id, data|
        if state == :delete and station_kvb_id == @station.kvb_id
          state = :keep
        end

        if state == :keep
          if station_kvb_id == destination.kvb_id
            state == :delete
          end
        end

        state == :delete
      end

      #raise remaining_route.inspect

      remaining_route.reduce(@travel_time_to_station) { |memo, row| memo += row.last[:travel_time_up] }
    end
  end

  def to_hash
    {
      line: self.line.number,
      id: self.id,
      kind: self.kind,
      position: self.position,
      destination: self.destination,
      direction: self.direction,
      speed: self.speed,
      arrival_time_at_destination: self.arrival_time_at_destination
    }
  end

end