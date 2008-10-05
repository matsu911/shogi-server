## $Id$

## Copyright (C) 2004 NABEYA Kenichi (aka nanami@2ch)
## Copyright (C) 2007-2008 Daigo Moriwaki (daigo at debian dot org)
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'shogi_server/util'

module ShogiServer

  class Pairing

    class << self
      def default_factory
        return sort_by_rate_with_randomness
      end

      def sort_by_rate_with_randomness
        return [ExcludeSacrificeGps500.new,
                MakeEven.new,
                SortByRateWithRandomness.new(1200, 2400),
                StartGame.new]
      end

      def random_pairing
        return [ExcludeSacrificeGps500.new,
                MakeEven.new,
                RandomPairing.new,
                StartGame.new]
      end

      def match(players)
        logics = default_factory
        logics.inject(players) do |result, item|
          item.match(result)
        end
      end
    end # class << self


    def match(players)
      # to be implemented
    end

    def include_newbie?(players)
      return players.find{|a| a.rate == 0} == nil ? false : true
    end

    def less_than_one?(players)
      if players.size < 1
        log_warning("Floodgate: At least one player is required")
        return true
      else
        return true
      end
    end

    def log_players(players)
      str_array = players.map do |one|
        if block_given?
          yield one
        else
          one.name
        end
      end
      log_message("Floodgate: [Players] %s" % [str_array.join(", ")])
    end
  end # Pairing

  class StartGame < Pairing
    def match(players)
      super
      if players.size < 2
        log_warning("There should be more than one player: %d" % [players.size])
        return
      end
      if players.size.odd?
        log_warning("There are odd players: %d" % [players.size])
      end

      log_players(players)
      while (players.size >= 2) do
        pair = players.shift(2)
        pair.shuffle!
        start_game(pair.first, pair.last)
      end
    end

    def start_game
      log_message("Floodgate: BLACK %s; WHITE %s" % [p1.name, p2.name])
      p1.sente = true
      p2.sente = false
      Game.new(p1.game_name, p1, p2)
    end
  end

  class Randomize < Pairing
    def match(players)
      super
      log_message("Floodgate: Randomize... before")
      log_players(players)
      players.shuffle!
      log_message("Floodgate: Randomized after")
      log_players(players)
    end
  end # RadomPairing

  class SortByRate < Pairing
    def match(players)
      super
      log_message("Floodgate: Ordered by rate")
      players.sort! {|a,b| a.rate <=> b.rate} # decendent order
      log_players(players)
    end
  end

  class SortByRateWithRandomness < Pairing
    def initialize(rand1, rand2)
      super()
      @rand1, @rand2 = rand1, rand2
    end

    def match(players)
      super
      cur_rate = Hash.new
      players.each{|a| cur_rate[a] = a.rate ? a.rate + rand(@rand1) : rand(@rand2)}
      players.sort!{|a,b| cur_rate[a] <=> cur_rate[b]}
      log_players(players) do |one|
        "%s %d (randomness %d)" % [one.name, one.rate, cur_rate[one] - one.rate]
      end
    end
  end

  class DeletePlayerAtRandom < Pairing
    def match(players)
      super
      return if less_than_one?(players)
      one = players.choice
      log_message("Floodgate: Deleted %s at random" % [one.name])
      players.delete(one)
      log_players(players)
    end
  end

  class DeletePlayerAtRandomExcept < Pairing
    def initialize(except)
      super()
      @except = except
    end

    def match(players)
      super
      log_message("Floodgate: Deleting a player at rondom except %s" % [@except.name])
      players.delete(@except)
      DeletePlayerAtRandom.new.match(players)
      players.push(@except)
    end
  end
  
  class DeleteMostPlayingPlayer < Pairing
    def match(players)
      super
      one = players.max_by {|a| a.win + a.loss}
      log_message("Floodgate: Deleted the most playing player: %s (%d)" % [one.name, one.win + one.loss])
      players.delete(one)
      log_players(players)
    end
  end

  class DeleteLeastRatePlayer < Pairing
    def match(players)
      super
      one = players.min_by {|a| a.rate}
      log_message("Floodgate: Deleted the least rate player %s (%d)" % [one.name, one.rate])
      players.delete(one)
      log_players(players)
    end
  end

  class ExcludeSacrifice < Pairing
    attr_reader :sacrifice

    # @sacrifice a player id to be eliminated
    def initialize(sacrifice)
      super()
      @sacrifice = sacrifice
    end

    def match(players)
      super
      if @sacrifice && 
         players.size.odd? && 
         players.find{|a| a.player_id == @sacrifice}
         log_message("Floodgate: Deleting the sacrifice %s" % [@sacrifice])
         players.delete_if{|a| a.player_id == @sacrifice}
         log_players(players)
      end
    end
  end # class ExcludeSacrifice

  class ExcludeSacrificeGps500 < ExcludeSacrifice
    def initialize
      super("gps500+e293220e3f8a3e59f79f6b0efffaa931")
    end
  end

  class MakeEven < Pairing
    def match(players)
      super
      return if players.even?
      log_message("Floodgate: there are odd players: %d. Deleting one..." % 
                  [players.size])
      DeletePlayerAtRandom.new.match(players)
    end
  end

end # ShogiServer
