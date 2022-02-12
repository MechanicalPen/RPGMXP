class Shadow_Line
  def initialize
    @shadows = Array.new
  end
  
  def is_in_shadow?(projection)
    for i in 0..(@shadows.length-1)
      if @shadows[i].covers?(projection) then return true end
    end
    return false  
  end
  
  def add(shadow)
    #Figure out where to slot the new shadow in the list.
    index = 0
    for i in 0..(@shadows.length-1)
      if (@shadows[index].start_val > shadow.start_val)
        break #Stop when we hit the insertion point.
      end
      index = index + 1
    end
    
    # The new shadow is going here. See if it overlaps the
    # previous or next.
    overlapping_previous = ((index > 0) &&
     (@shadows[index-1].end_val > shadow.start_val))
     
    overlapping_next = ((index < @shadows.length) &&
        (@shadows[index].start_val < shadow.end_val))
        
    # Insert and unify with overlapping shadows.
    if overlapping_next
      if overlapping_previous
        # Overlaps both, so unify one and delete the other
        @shadows[index - 1].end_val =
         [@shadows[index - 1].end_val, @shadows[index].end_val].max
        @shadows.delete_at(index)
      else
        # Overlaps the next one, so unify it with that.
        @shadows[index].start_val =
          [@shadows[index].start_val, shadow.start_val].min
      end
    else
      if overlapping_previous
        # Overlaps the previous one, so unify it with that.
        @shadows[index - 1].end_val =
          [@shadows[index - 1].end_val, shadow.end_val].max
      else
        # Does not overlap anything, so insert.
        @shadows.insert(index, shadow)
      end
    end
  end
  
  def is_full_shadow?
    return @shadows.length == 1 &&
           @shadows[0].start_val <= 0.0 &&
           @shadows[0].end_val >= 1.0
  end
         
end

class Shadow
  attr_accessor :start_val
  attr_accessor :end_val
  
  def initialize(start_it, end_it)
    @start_val = start_it
    @end_val = end_it
  end
  
  #returns 'true' if other is completely covered by this shadow.
  def covers?(other)
    return start_val <= other.start_val && end_val >= other.end_val
  end
end

#==============================================================================
# ** Fog of War
#------------------------------------------------------------------------------
# Version 2.0, 2005-11-21
# by Wachunga
#==============================================================================
=begin
 0.8 - original release
 0.85
   - added colour parameter to map names
   - fixed bug where map grids overlapped
 0.9
   - switched over to a tilemap (from a sprite)
   - now more compatible with minimap scripts (but they'll have to take
   extra tilemap into account)
 1.0
   - switched over to an autotile instead of using a custom tileset
     * edges looks nicer, but gradual fading had to be removed
     * colour parameter no longer possible (set by autotile)
   - move event (including jumping and speed changes) bug fixed
   - teleportation bug fixed
   - some optimization
   - made compatible with Cogwheel's Pixel Movement script
     (see http://www.rmxp.net/forums/index.php?showtopic=24716 for details)
 1.01
   - fixed bug when teleporting from map without fow to a map with fow
 2.0
   - now two independent types of fog of war:
      * static, which never returns (i.e. typical RTS "terrain" fog)
      * dynamic, which returns once out of visual range and can optionally
        hide map events (i.e. typical RTS "unit" fog)
   - now using a compact version of Near's Dynamic Maps script
   - fog of war is now above weather and normal fog
   - added support for much larger visual ranges (0 - 9)
   - added support for option to set up fog of war from a call script event
     command
   - optimization

 A map specified as having "fog of war" (fow) has tiles that are (fully or
 partially) obscured until the player gets within visual range. The amount of
 fow to disappear as the player moves depends on the visual range specified.
 Gamers with experience playing Real Time Strategy games like Warcraft, Age of
 Empires, etc. should be quite familiar with the concept.

 This script supports two kinds of fog of war: static and dynamic.

 Static fow is the kind that typically hides terrain in RTS games. It covers
 the entire map until the player explores the area, discovering the underlying
 terrain. Once static fow disappears from an area of the map, it stays gone
 indefinitely (even if loading a saved game, leaving the map and returning
 later, going to the menu, etc).

 Dynamic fow is identical to the static kind except that it doesn't stay gone
 forever: as soon as the player leaves visual range of an explored tile,
 dynamic fow covers it again. This kind of fow is typically used to hide enemy
 units in RTS games.

 SETUP:
 
 There's no need to add the autotile via the database. Just place the
 file in the autotile folder, import it, and change the FOW_AT_NAME constant
 to the appropriate filename. To change the colour of the fog of war you must
 create a new autotile. (However, opacity is customizable by constants below.)
 
 To indicate a map is to have either (or both) of these kinds of fog of war,
 include <fow> in its name (via "Map properties"). To enable both static and
 dynamic fow, you can either add nothing more (since it's the default), or
 add <s><d> (or <d><s>). To enable one or the other, just add the appropriate
 one (e.g. <s> for static, <d> for dynamic). You may also optionally specify a
 visual range between 0 and 9 in the map name (e.g. <5>), noting that 3 is
 the default. Here are some example map names:
 "your-map-name <fow><2>" (defaults to static&dynamic on; range specified as 2)
 "your-map-name <fow><s>" (only static fow is on; range defaults to 3)
 "your-map-name <fow><d><8>" (only dynamic fow is on; range specified as 8)
 
 Alternatively, fog of war can be setup via a call script event command using
 the fog_of_war global method. Detailed instructions are just before
 the method itself.

 Finally, an edited version of Near Fantastica's Dynamic Maps script needs
 to be below this one. You may find it at the following URL:
 http://www.rmxp.net/forums/index.php?showtopic=24716
 
 The ranges work as follows:
 range = 0 reveals just the square on which the player stands

 range = 1 is the same as range 0 plus four adjacent tiles
 i.e.   @
       @P@
        @

 range = 2 is the same as range 1 plus eight additional tiles
  i.e.  @
       @@@
      @@P@@
       @@@
        @

 range = 3 (default) is the same as range 2 plus twelve additional tiles
  i.e.  @
       @@@
      @@@@@
     @@@P@@@
      @@@@@
       @@@
        @

 etc.

 Note: I've taken great pains to optimize this script as much as possible
 (which unfortunately reduces the readability of the code). There shouldn't be
 much visible effect on frame rate.

=end

#------------------------------------------------------------------------------
 # filename of the fog of war autotile (used for both):
 FOW_AT_NAME = 'fow_default'
 # the opacity of static (non-returning) and dynamic (returning) fog of war
 # (value between 0 and 255)
 # note that static fow appears on top of its dynamic counterpart (if both on)
 FOW_STATIC_OPACITY = 255
 FOW_DYNAMIC_OPACITY = 100
 # whether or not dynamic fow hides map events
 FOW_DYNAMIC_HIDES_EVENTS = true
 # default range of fog of war (if not specified in map name)
 FOW_RANGE_DEFAULT = 9
#------------------------------------------------------------------------------
 # internal constants - no need to edit
 FOW = 0b00
 REVEALED = 0b01
 # tiles with no surrounding fog are flagged "SKIP" for efficiency
 SKIP = 0b10
#------------------------------------------------------------------------------

=begin
 Setup fog of war.
 
 This method is an alternative to using the default map name method, and
 is designed to be called from a call script event command. This allows
 fog of war to be dynamically enabled or disabled during gameplay.
 
 Parameters:
 static - if true, static fow enabled
 dynamic - if true, dynamic fow enabled
 (if both of the above are false, fow is totally disabled)
 range (optional) - the visual range of the player
                    * default is FOW_RANGE_DEFAULT
 reset (optional) - if true, fow for this map resets entirely (i.e. previously
                    explored areas are covered again)
                    * default is false
                    
 Sample calls:
 fog_of_war(true,true,5) - enable both static and dynamic fow with range of 5
 fog_of_war(false,false,3,true) - disable and reset both types of fow
=end
def fog_of_war(static, dynamic, range = FOW_RANGE_DEFAULT, reset = false)
  if static == nil or dynamic == nil
    print 'Two true/false parameters are required in call to fog_of_war.'
    exit
  elsif range < 0 or range > 9
    print 'Invalid range in call to fog_of_war (only 0-9 is valid).'
    exit
  end
  $game_map.fow_static = static
  $game_map.fow_dynamic = dynamic
  $game_map.fow_range = range
  if reset
    $game_map.fow_grid = nil
  end
  if not $game_map.fow_static and not $game_map.fow_dynamic
    $game_map.fow = false
    $scene.spriteset.fow_tilemap.dispose
    # set all events back to visible
    for i in $game_map.events.keys
      $game_map.events[i].transparent = false
    end
  else
    # static or dynamic fow (or both) are on
    $game_map.fow = true
    if $game_map.fow_grid == nil # only if not already defined
      $game_map.fow_grid = Table.new($game_map.width, $game_map.height, 2)
      for i in 0...$game_map.fow_grid.xsize
        for j in 0...$game_map.fow_grid.ysize
          $game_map.fow_grid[i,j,1] = $game_map.fow_grid[i,j,0] = FOW
        end
      end
    end
    if $game_map.fow_dynamic
      $game_map.fow_revealed = $game_map.fow_last_revealed = []
    end
    $scene.spriteset.initialize_fow
  end    
end

class Game_Map
 attr_accessor :fow
 attr_accessor :fow_static
 attr_accessor :fow_dynamic 
 attr_accessor :fow_grid
 attr_accessor :fow_range
 attr_accessor :fow_revealed
 attr_accessor :fow_last_revealed

 alias wachunga_fow_gm_setup setup
 def setup(map_id)
   wachunga_fow_gm_setup(map_id)
   @fow = false
   @fow_dynamic = false
   @fow_static = false
   @fow_grid = nil
   @fow_range = nil
   # get any tags from the map name
   tags = $game_map.map_name.delete(' ').scan(/<[A-Za-z0-9_.,]+>/)
   if not tags.empty? and tags[0].upcase == ('<FOW>')
     tags.shift # remove FOW tag
     @fow = true
     if @fow_grid == nil # only if not already defined
       @fow_grid = Table.new(@map.width, @map.height, 2)
       for i in 0...@fow_grid.xsize
         for j in 0...@fow_grid.ysize
           @fow_grid[i,j,1] = @fow_grid[i,j,0] = FOW
         end
       end
     end
     # check if types of fog of war specified
     while not tags.empty?
       case tags[0].upcase
       when '<S>'
         @fow_static = true
       when '<D>'
         @fow_dynamic = true
       else
         x = tags[0].delete('<>').to_i
         @fow_range = x if x >= 0 and x <= 9
       end
       tags.shift
     end
     # if <FOW> tag found but neither static nor dynamic specified, assume both
     if @fow and not @fow_static and not @fow_dynamic
       @fow_static = true
       @fow_dynamic = true
     end
     # if no range specified, set to default
     if @fow_range == nil
       @fow_range = FOW_RANGE_DEFAULT
     end
     @fow_revealed = @fow_last_revealed = [] if @fow_dynamic
   end
 end

 def map_name
   return load_data('Data/MapInfos.rxdata')[@map_id].name
 end

  def transform_octant(row, col, octant)
    case octant
    when 0
      return [col, -row]
    when 1
      return [row, -col]
    when 2
      return [row, col]
    when 3
      return [col, row]
    when 4
      return [-col, row]
    when 5
      return [-row, col]
    when 6
      return [-row, -col]
    when 7
      return [-col, -row]
    end
  end
  
  def project_tile(row, col)
    row_f = row.to_f
    col_f = col.to_f
    
    top_left = col_f / (row_f + 2.0)
    bottom_right = (col_f + 1.0) / (row_f + 1.0)
    #p "top_left = " + top_left.to_s + "  bottom_right = " + bottom_right.to_s
    return Shadow.new(top_left, bottom_right)
  end
  
  def update_fow_grid
    update_fow_grid_static
    if @fow_dynamic
      #player can always see the tile they are standing on.
      @fow_grid[$game_player.x,$game_player.y,0] |= REVEALED
      @fow_revealed.push([$game_player.x,$game_player.y])
      
      #check dynamic vision in eighths
      for octant in 0..7
        update_fow_grid_eighth(octant)
      end
      
     if @fow_last_revealed != []
       # make dynamic fog return once out of visual range
       for t in @fow_last_revealed - @fow_revealed
         @fow_grid[t[0],t[1],0] = FOW
         for i in t[0]-1 .. t[0]+1
           for j in t[1]-1 .. t[1]+1
             # we need to unset SKIP on surroundings
             # to update the autotile properly.
             if !$game_map.valid?(i,j) then next end
             @fow_grid[i,j,0] &= ~SKIP
           end
         end
       end
     end
     @fow_last_revealed = @fow_revealed
     @fow_revealed = []
    end
  end
  
  def update_fow_grid_eighth(octant)
    max_row = 19 #maximum screen tiles, lower if you experience lag.
    line = Shadow_Line.new
    full_shadow = false
    
    for row in 1..max_row
      pos_x, pos_y = transform_octant(row, 0, octant)
      pos_x = $game_player.x +  pos_x
      pos_y = $game_player.y + pos_y
      # stop if we go out of bounds 
      if !valid?(pos_x,pos_y) then break end
      
      for col in 0..row
        pos_x, pos_y = transform_octant(row, col, octant)
        pos_x = $game_player.x +  pos_x
        pos_y = $game_player.y + pos_y
        # if we are out of the map bail on this col 
        if !valid?(pos_x,pos_y) then break end
          
        if (!full_shadow)
          projection = project_tile(row, col)
          #set this visibility of this tile
          visible = !line.is_in_shadow?(projection)
          if visible && @fow_dynamic
            @fow_grid[pos_x,pos_y,0] |= REVEALED
            @fow_revealed.push([pos_x,pos_y])
          end
          #add any opaque tiles to the shadow map.
          if visible && !(passable?(pos_x, pos_y, 10) ||
                          terrain_tag(pos_x, pos_y) == 1)
            line.add(projection)
            full_shadow = line.is_full_shadow?
          end
        end
      end
      
    end
  end
  
=begin
 Updates the map's grid which keeps track of one or both of the following
 (depending on what is enabled for the current map):
 1) which tiles have been "discovered" (i.e. no static fog of war) based on
    where the player has already explored
 2) which tiles are currently not covered by dynamic fog of war (i.e. not in
    visual range)
=end
 def update_fow_grid_static
   px = $game_player.x
   py = $game_player.y
   x = px - @fow_range
   start_y = py
   y = start_y
   count = 1
   mod = 1
   # loop through all tiles in visible range
   until x == (px + @fow_range+1)
     i = count
     while i > 0
       if valid?(x,y)
         if @fow_static
           @fow_grid[x,y,1] |= REVEALED
         end
       end
       y -= 1
       i -= 1
     end
     if x == px
       mod = -1
     end
     x += 1
     start_y += 1*mod
     y = start_y
     count += 2*mod
   end
 end  
 
end

#------------------------------------------------------------------------------

class Spriteset_Map

 attr_reader :fow_tilemap
  
 alias wachunga_fow_ssm_initialize initialize
 def initialize
   initialize_fow if $game_map.fow
   wachunga_fow_ssm_initialize
 end

=begin
 Initializes fog of war.
=end 
 def initialize_fow
   @fow_tilemap = Tilemap.new     
   @fow_tilemap.map_data = Table.new($game_map.width, $game_map.height, 3)
   @fow_tilemap.priorities = Table.new(144)
   @fow_autotiles = Hash.new(0)
   j = 48 # starting autotile index
   for i in Autotile_Keys
     @fow_autotiles[i] = j
     j += 1
   end
   # add duplicates
   for i in Duplicate_Keys.keys
     @fow_autotiles[i] = @fow_autotiles[Duplicate_Keys[i]]
   end     
   if $game_map.fow_static
     for m in 0...$game_map.fow_grid.xsize
       for n in 0...$game_map.fow_grid.ysize
         # reset SKIP flag
         $game_map.fow_grid[m,n,1] &= ~SKIP
       end
     end
     at = Bitmap.new(96,128)
     at.blt(0,0,RPG::Cache.autotile(FOW_AT_NAME),\
            Rect.new(0,0,96,128),FOW_STATIC_OPACITY)       
     @fow_tilemap.autotiles[0] = at
     # set everything to fog
     for x in 0...$game_map.width
       for y in 0...$game_map.height
         @fow_tilemap.map_data[x,y,2] = 48 # fog
       end
     end
     # set to highest priority
     for i in 48...96
       @fow_tilemap.priorities[i] = 5
     end
   end
   if $game_map.fow_dynamic
     bm = Bitmap.new(96,128)
     bm.blt(0,0,RPG::Cache.autotile(FOW_AT_NAME),\
            Rect.new(0,0,96,128),FOW_DYNAMIC_OPACITY)
     @fow_tilemap.autotiles[1] = bm
     # unlike tilemap for static, set everything to clear
     for x in 0...$game_map.width
       for y in 0...$game_map.height
         @fow_tilemap.map_data[x,y,1] = 0
       end
     end
     # set to highest priority
     for i in 96...144
       @fow_tilemap.priorities[i] = 5
     end
   end
   $game_map.update_fow_grid
   update_fow_tilemap
   update_event_transparency if $game_map.fow_dynamic
 end
 
 
=begin
 Updates the (static and/or dynamic) fog of war tilemap based on the map's
 underlying grid.
=end
 def update_fow_tilemap
   if $game_map.fow_static
     checked_static = Table.new($game_map.width,$game_map.height)
     for j in 0...$game_map.width
       for k in 0...$game_map.height
         checked_static[j,k] = 0
       end
     end
   end
   if $game_map.fow_dynamic
     checked_dynamic = Table.new(23,18)
     for j in 0...23
       for k in 0...18
         checked_dynamic[j,k] = 0
       end
     end
   end
   
   dx = ($game_map.display_x/128).round
   dy = ($game_map.display_y/128).round
   
   #turn dynamic tiles to their natural state.
   if $game_map.fow_dynamic
     for x in dx-1 .. dx+21
       for y in dy-1 .. dy+17
         # check boundaries
         if !$game_map.valid?(x,y) then next end
         if $game_map.fow_grid[x,y,0] == FOW
           @fow_tilemap.map_data[x,y,1] = 96 if @fow_tilemap.map_data[x,y,1]!=96
         end
       end
     end
   end
   # to increase performance, only process fow currently on the screen
   for x in dx-1 .. dx+21
     for y in dy-1 .. dy+16
       # check boundaries
       if !$game_map.valid?(x,y) then next end
       if $game_map.fow_dynamic
         if $game_map.fow_grid[x,y,0] == REVEALED # (but not SKIP)
           others = false; 
           @fow_tilemap.map_data[x,y,1] = 0 if @fow_tilemap.map_data[x,y,1]!=0
           for i in x-1 .. x+1
             for j in y-1 .. y+1
               # check new boundaries
               if !$game_map.valid?(i,j) then next end
               if $game_map.fow_grid[i,j,0] == FOW
                 others = true # can't flag as SKIP because there's nearby fog
                 if checked_dynamic[(i - dx - 1),(j - dy + 2)] == 0
                   checked_dynamic[(i - dx - 1),(j - dy + 2)] = 1
                   # only fill if not already revealed
                   if @fow_tilemap.map_data[i,j,1] != 0
                     adj = check_adjacent(i,j,0,$game_map.fow_grid,REVEALED)
                     if adj != nil
                       @fow_tilemap.map_data[i,j,1] =
                         (eval '@fow_autotiles[adj.to_i]') + 48
                     end
                   end
                 end
               end
             end
           end
           if !others
             # no adjacent static fog found, so flag tile to avoid reprocessing
             $game_map.fow_grid[x,y,0] |= SKIP
           end
         end    
       end # fow_dynamic        
       if $game_map.fow_static
         if $game_map.fow_grid[x,y,1] == REVEALED # (but not SKIP)
           others = false; 
           @fow_tilemap.map_data[x,y,2] = 0 if @fow_tilemap.map_data[x,y,2]!=0
           for i in x-1 .. x+1
             for j in y-1 .. y+1
               # check new boundaries
               if !$game_map.valid?(i,j) then next end
               if $game_map.fow_grid[i,j,1] == FOW
                 others = true # can't flag as SKIP because there's nearby fog
                 if checked_static[i,j] == 0
                   checked_static[i,j] = 1
                   # only fill if not already revealed
                   if @fow_tilemap.map_data[i,j,2] != 0
                     adj = check_adjacent(i,j,1,$game_map.fow_grid,REVEALED)
                     if adj != nil
                       @fow_tilemap.map_data[i,j,2] =
                         eval '@fow_autotiles[adj.to_i]'
                     end
                   end
                 end
               end
             end
           end
           if !others
             # no adjacent static fog found, so flag tile to avoid reprocessing
             $game_map.fow_grid[x,y,1] |= SKIP
           end
         end    
       end # fow_static
     end # for
   end # for
 end

=begin
 Update event transparency based on dynamic fog.
 
 Note that if a specific character is passed as a parameter then only
 its transparency is updated; otherwise, all events are processed.
=end
 def update_event_transparency(pChar = nil)
   return if not FOW_DYNAMIC_HIDES_EVENTS
   if pChar == nil
     # check them all
     for i in $game_map.events.keys
       event = $game_map.events[i]
       if $game_map.fow_grid[event.x,event.y,0] == FOW
         event.transparent = true
       else
         event.transparent = false
       end
     end
   else
     # just check the one
     pChar.transparent=($game_map.fow_grid[pChar.x,pChar.y,0]==FOW) ?true:false
   end
 end
 
 # create a list of tiles adjacent to a specific tile that don't match a flag
 # (used for calculating tiles within an autotile)
 def check_adjacent(i,j,k,grid,flag)
   return if not $game_map.valid?(i,j) or grid == nil or flag == nil
   adj = ''
   if (i == 0)
     adj << '147'
   else
     if (j == 0) then adj << '1'
     else
       if (grid[i-1,j-1,k] != flag) then adj << '1' end
     end
     if (grid[i-1,j,k] != flag) then adj << '4' end
     if (j == $game_map.height-1) then adj << '7'
     else
       if (grid[i-1,j+1,k] != flag) then adj << '7' end
     end
   end
   if (i == $game_map.width-1)
     adj << '369'
   else
     if (j == 0) then adj << '3'
     else
       if (grid[i+1,j-1,k] != flag) then adj << '3' end
     end
     if (grid[i+1,j,k] != flag) then adj << '6' end
     if (j == $game_map.height-1) then adj << '9'
     else
       if (grid[i+1,j+1,k] != flag) then adj << '9' end
     end
   end
   if (j == 0)
     adj << '2'
   else
     if (grid[i,j-1,k] != flag) then adj << '2' end
   end
   if (j == $game_map.height-1)
     adj << '8'
   else
     if (grid[i,j+1,k] != flag) then adj << '8' end
   end
   # if no adjacent fog, set it as 0
   if (adj == '') then adj = '0' end
   # convert to an array, sort, and then back to a string
   return adj.split(//).sort.join
 end

 alias wachunga_fow_ssm_dispose dispose
 def dispose
   @fow_tilemap.dispose if @fow_tilemap != nil
   wachunga_fow_ssm_dispose
 end

 alias wachunga_fow_ssm_update update
 def update
   if $game_map.fow
     @fow_tilemap.ox = $game_map.display_x / 4
     @fow_tilemap.oy = $game_map.display_y / 4
     @fow_tilemap.update
   end
   wachunga_fow_ssm_update
 end
end

#------------------------------------------------------------------------------

class Game_Character
  alias wachunga_fow_gch_initialize initialize
  def initialize
    wachunga_fow_gch_initialize
    @last_x = @x
    @last_y = @y
  end

  alias wachunga_fow_gch_update_move update_move
  def update_move
    wachunga_fow_gch_update_move
    if $game_map.fow
      if $game_map.fow_dynamic and (@x != @last_x or @y != @last_y)\
        and self != $game_player
        # check if character entered/left player's visual range
        $scene.spriteset.update_event_transparency(self)
      end
    end
    @last_x = @x
    @last_y = @y
  end
end

#------------------------------------------------------------------------------

class Game_Player

 def update_jump
   super
   # only update when about to land, not revealing anything jumped over
   if $game_map.fow and @jump_count == 0
     $game_map.update_fow_grid
     $scene.spriteset.update_event_transparency if $game_map.fow_dynamic
     $scene.spriteset.update_fow_tilemap
   end
 end

 def update_move
   if $game_map.fow and (@x != @last_x or @y != @last_y)
     unless jumping?
       $game_map.update_fow_grid
       $scene.spriteset.update_event_transparency if $game_map.fow_dynamic
       $scene.spriteset.update_fow_tilemap
     end
   end
   super
 end

end

#------------------------------------------------------------------------------

class Scene_Map
 attr_reader :spriteset
end

=begin
       Autotile in column 2:

row\col| 1  2  3  4  5  6  7  8
    ---------------------------
    1 | 48 49 50 51 52 53 54 55
    2 | 56 57 58 59 60 61 62 63
    3 | 64 65 66 67 68 69 70 71
    4 | 72 73 74 75 76 77 78 79
    5 | 80 81 82 83 84 85 86 87
    6 | 88 89 90 91 92 93 94 95

    The function to return the index of a single tile within an autotile
    (given by at_index) is (at_index-1)*48 + col-1 + (row-1)*8
    (where row, col, and at_index are again NOT zero-indexed)
=end

=begin
   The following array lists systematic keys which are based on adjacent
   walls (where 'W' is the wall itself):
   1 2 3
   4 W 6
   7 8 9
   e.g. 268 is the key that will be used to refer to the autotile
   which has adjacent walls north, east, and south.  For the Castle Prison
   tileset (autotile #1), this is 67.

   (It's a bit unwieldy, but it works.)
=end

 Autotile_Keys = [
 12346789,
 2346789,
 1246789,
 246789,
 1234678,
 234678,
 124678,
 24678,

 1234689,
 234689,
 124689,
 24689,
 123468,
 23468,
 12468,
 2468,

 23689,
 2689,
 2368,
 268,
 46789,
 4678,
 4689,
 468,

 12478,
 1248,
 2478,
 248,
 12346,
 2346,
 1246,
 246,

 28,
 46,
 689,
 68,
 478,
 48,
 124,
 24,

 236,
 26,
 8,
 6,
 2,
 4,
 0 ]

 # many autotiles handle multiple situations
 # this hash keeps track of which keys are identical
 # to ones already defined above
 Duplicate_Keys = {
 123689 => 23689,
 236789 => 23689,
 1236789 => 23689,
 34689 => 4689,
 14689 => 4689,
 134689 => 4689,
 14678 => 4678,
 34678 => 4678,
 134678 => 4678,
 146789 => 46789,
 346789 => 46789,
 1346789 => 46789,
 23467 => 2346,
 23469 => 2346,
 234679 => 2346,
 123467 => 12346,
 123469 => 12346,
 1234679 => 12346,
 12467 => 1246,
 12469 => 1246,
 124679 => 1246,
 124789 => 12478,
 123478 => 12478,
 1234789 => 12478,
 146 => 46,
 346 => 46,
 467 => 46,
 469 => 46,
 1346 => 46,
 1467 => 46,
 1469 => 46,
 3467 => 46,
 3469 => 46,
 4679 => 46,
 13467 => 46,
 13469 => 46,
 14679 => 46,
 34679 => 46,
 134679 => 46,
 128 => 28,
 238 => 28,
 278 => 28,
 289 => 28,
 1238 => 28,
 1278 => 28,
 1289 => 28,
 2378 => 28,
 2389 => 28,
 2789 => 28,
 12378 => 28,
 12389 => 28,
 12789 => 28,
 23789 => 28,
 123789 => 28,

 1247 => 124,
 2369 => 236,
 147 => 4,
 247 => 24,
 14 => 4,
 47 => 4,
 1478 => 478,
 3478 => 478,
 4789 => 478,
 134789 => 478,
 14789 => 478,
 13478 => 478,
 34789 => 478,
 1234 => 124,
 1247 => 124,
 1249 => 124,
 12347 => 124,
 12349 => 124,
 12479 => 124,
 123479 => 124,
 1236 => 236,
 2367 => 236,
 2369 => 236,
 12367 => 236,
 12369 => 236,
 23679 => 236,
 123679 => 236,
 12368 => 2368,
 23678 => 2368,
 123678 => 2368,
 12348 => 1248,
 12489 => 1248,
 123489 => 1248,
 1689 => 689,
 3689 => 689,
 6789 => 689,
 13689 => 689,
 16789 => 689,
 36789 => 689,
 136789 => 689,
 12689 => 2689,
 26789 => 2689,
 126789 => 2689,
 23478 => 2478,
 24789 => 2478,
 234789 => 2478,

 12 => 2,
 23 => 2,
 27 => 2,
 29 => 2,
 123 => 2,
 127 => 2,
 129 => 2,
 237 => 2,
 239 => 2,
 279 => 2,
 1237 => 2,
 1239 => 2,
 1279 => 2,
 2379 => 2,
 12379 => 2,


 14 => 4,
 47 => 4,
 34 => 4,
 49 => 4,
 147 => 4,
 134 => 4,
 347 => 4,
 349 => 4,
 149 => 4,
 479 => 4,
 1347 => 4,
 1479 => 4,
 1349 => 4,
 3479 => 4,
 13479 => 4,

 16 => 6,
 36 => 6,
 67 => 6,
 69 => 6,
 136 => 6,
 167 => 6,
 169 => 6,
 367 => 6,
 369 => 6,
 679 => 6,
 1369 => 6,
 3679 => 6,
 1367 => 6,
 1679 => 6,
 13679 => 6,

 78 => 8,
 89 => 8,
 18 => 8,
 38 => 8,
 138 => 8,
 789 => 8,
 178 => 8,
 189 => 8,
 378 => 8,
 389 => 8,
 1789 => 8,
 3789 => 8,
 1378 => 8,
 1389 => 8,
 13789 => 8,

 1468 => 468,
 3468 => 468,
 13468 => 468,

 2467 => 246,
 2469 => 246,
 24679 => 246,

 2348 => 248,
 2489 => 248,
 23489 => 248,

 1268 => 268,
 2678 => 268,
 12678 => 268,

 148 => 48,
 348 => 48,
 489 => 48,
 1348 => 48,
 1489 => 48,
 3489 => 48,
 13489 => 48,

 168 => 68,
 368 => 68,
 678 => 68,
 1368 => 68,
 1678 => 68,
 3678 => 68,
 13678 => 68,

 234 => 24,
 247 => 24,
 249 => 24,
 2347 => 24,
 2349 => 24,
 2479 => 24,
 23479 => 24,

 126 => 26,
 267 => 26,
 269 => 26,
 1267 => 26,
 1269 => 26,
 2679 => 26,
 12679 => 26,
 }
 
 #================================
# ■ Dynamic Maps
#================================
# 　By: Near Fantastica
#   Date: 05.09.05
#   Version: 1
#================================

# updated 2005-11-07 by Wachunga
# generalized to work for modified versions of Game_Map,
# e.g. even if more instance variables are added

module Map
  #--------------------------------------------------------------
  @map_data = {}
  #--------------------------------------------------------------------------
  def Map.set_map(map, map_id)
    @map_data[map_id] = map
  end
  #--------------------------------------------------------------------------
  def Map.data(map_id)
    return @map_data[map_id]
  end
end

class Game_Map
 #--------------------------------------------------------------
  alias dm_orig_setup setup
  def setup(map_id)
    save_map(@map_id)
    if Map.data(map_id) == nil
      dm_orig_setup(map_id)
    else
      load_map(map_id)
    end
  end
 #-----------------------------------------------------------
 def load_map(map_id)
   $game_map = Map.data(map_id)
 end
 #--------------------------------------------------------------
 def save_map(map_id)
   return if map_id == 0
   Map.set_map(self.dup, map_id)
 end
end