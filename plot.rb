require 'plotrb'
require 'yaml'
require 'pry'
require 'date'

HEIGHT = {'minerals' => 300, 'missions' => 500}
WIDTH=600

raise("Requires 'minerals' or 'missions' as an argument and an optional height") if ARGV.size == 0
height = ARGV.size > 1 ? ARGV[1].to_i : HEIGHT[ARGV[0]]


def parse_date d
  if d.is_a?(Fixnum)
    Date.new(d)
  elsif d == "future"
    Date.new(2015)
  elsif d.include?(',')
    Date.parse(d.split(',')[0])
  else
    Date.parse(d)
  end
end

# Extract the spectra from a minerals dataset.
def spectra_from_minerals minerals, cutoffs
  m = []
  pos = 0
  minerals.each do |key, s|
    s.each do |low_high|
      next if low_high[0] > cutoffs[1]
      #low_high[1] = 5000 if low_high[1] > 5000
      m << { :id => key, :low => low_high[0], :high => low_high[1], :pos => pos }
      pos += 1
    end
  end
  m.sort_by { |x| x[:pos] }
end

# Extract the spectra from the sensors for each mission
def spectra_from_missions resources
  missions    = resources[:missions]
  atmospheres = resources[:atmospheres]

  has         = atmospheres.select { |k,v| v == true }.keys
  hasnot      = atmospheres.select { |k,v| v == false }.keys

  spectra     = Hash.new { |h,k| h[k] = [] }

  missions.each do |mission|
    unless mission.has_key?(:launch)
      STDERR.puts "Launch date missing for item #{mission.inspect}"
    end

    # Determine whether we're looking at a place with an atmosphere or not.
    #binding.pry
    unless mission[:destinations].nil?
      no_atmosphere = mission[:destinations] & hasnot
      next if no_atmosphere.empty?
    end

    #puts "mission #{mission.inspect}"
    mission[:sensors].each do |sensor|
      #puts "\tsensor #{sensor.inspect}"
      if sensor.has_key?(:spectra) && !sensor[:spectra].nil?
        sensor[:spectra].each do |spectrum|
          spectra[sensor[:abbrev] || sensor[:name]] << spectrum.merge({
            :mission => (mission[:abbrev] || mission[:name]),
            :launch  => parse_date(mission[:launch]),
            :width   => sensor[:width] || 1024
          })
        end
      else
        STDERR.puts "sensor #{sensor[:abbrev] || sensor[:name]} on #{mission[:abbrev] || mission[:name]} is missing spectra"
      end
    end
  end

  spectra
end

# Ensure that all the spectra have low, high, and resolution set, at the very least. Also eliminate spectra that fall
# beyond the cutoff.
def cleanup_mission_spectra spectra, cutoffs
  spectra.each_pair do |key,ary|
    ary.each.with_index do |item,i|
      extra = {
          :id => key,
        }

      if item.has_key?(:peak)
        extra[:mean] = item[:peak]

        # Make sure it has a low and a high
        if !item.has_key?(:low) && !item.has_key?(:high)
          unless item.has_key?(:resolution)
            raise("resolution missing for item #{item.inspect}")
          end
          extra[:low]  = item[:peak] - item[:resolution]/2.0
          extra[:high] = item[:peak] + item[:resolution]/2.0
        elsif item.has_key?(:low) && !item.has_key?(:high)
          extra[:high] = item[:low] + item[:resolution]
        elsif item.has_key?(:high) && !item.has_key?(:low)
          extra[:low] = item[:high] - item[:resolution]
        end
      elsif item.has_key?(:low)
        if item.has_key?(:high)
          extra[:mean] = (item[:low] + item[:high]) / 2.0
        else
          extra[:mean] = (2*item[:low] + item[:resolution]) / 2.0 # no high given
        end
      elsif item.has_key?(:high)
        extra[:mean] = (2*item[:high] - item[:resolution]) / 2.0 # no low given
      end

      spectra[key][i] = item.merge(extra)

      # Make sure we have a resolution for the heatmap
      spectra[key][i][:resolution] ||= spectra[key][i][:high] - spectra[key][i][:low]
      spectra[key][i][:low] = cutoffs[0] if spectra[key][i][:low] < cutoffs[0]
    end
    #binding.pry
    #spectra[key].sort_by { |s| -s[:resolution] }
  end

  spectra = spectra.values.flatten.sort_by { |s| s[:resolution] }.sort_by { |s| s[:launch] }
  spectra.delete_if { |s| s[:low] > cutoffs[1] }

  spectra
end

def load_yaml filename
  YAML.load(File.read(filename))
end

extracted_spectra = spectra_from_missions(load_yaml('missions.yaml'))
spectra           = cleanup_mission_spectra(extracted_spectra, [100,5000])
minerals          = spectra_from_minerals(load_yaml('minerals.yaml'), [100,5000])

missions_data = pdata.name('spectra').values(spectra)
minerals_data = pdata.name('minerals').values(minerals)

global_x = pow_scale.name('x').from('spectra.mean').exponent(0.5).domain([200,5000]).range([-99.0, WIDTH.to_f])

missions_y = ordinal_scale.name('sensors').from('spectra.mission').range([0, height])
minerals_y = ordinal_scale.name('absorbances').from('minerals.id').range([0, height])
missions_resolution = log_scale.name('c').from('spectra.resolution').domain([0.1,1000.0]).range(['blue', 'red'])

max_w = height / spectra.map { |s| s[:mission] }.sort.uniq.size.to_f - 2.0
missions_w = log_scale.name('w').from('spectra.width').domain([1,5024]).range([2.0, max_w])

missions_rectangles = rect_mark.from(missions_data) do
  enter do
    x_start  { scale(global_x).from(:low) }
    x_end    { scale(global_x).from(:high)}
    y_start  { scale(missions_y).from(:mission).offset(max_w/2.0 + 1.0) }
    height   { scale(missions_w).from(:width) }
    fill     { scale(missions_resolution).from(:resolution) }
    fill_opacity 0.9
    #stroke   { scale(rgbs).from(:peak) }
  end
end

minerals_rectangles = rect_mark.from(minerals_data) do
  enter do
    x_start   { scale(global_x).from(:low)  }
    x_end     { scale(global_x).from(:high) }
    y_start   { scale(minerals_y).from(:id) }
    height    { scale(minerals_y).offset(-1).use_band }
    fill 'black'
    fill_opacity 0.5
  end
end

resolutions_legend = legend do
  fill missions_resolution
  title "Sampling interval"
  offset 10

  properties do
    symbols do
      fill_opacity 0.6
    end

    #x WIDTH
  end
end

missions_y_axis = y_axis.scale(missions_y).with_grid.layer(:back)
minerals_y_axis = y_axis.scale(minerals_y)

def visualize which_x_scale, which_y_scale, which_other_scales, which_marks, which_data, height, which_y_axis, which_legend=nil

  visualization.width(WIDTH).height(height) do
    padding top: 10, left: 140, bottom: 60, right: 200
    data which_data
    scales which_x_scale, which_y_scale, *which_other_scales
    marks *which_marks
    legends(which_legend) unless which_legend.nil?
    axes x_axis.scale(which_x_scale).values([100,300,600,1000,1750,2500,5000]).with_grid.layer(:back).title("Wavelength (nm)"),
         which_y_axis
  end
end

vis = begin
  if ARGV[0] == 'missions'
    STDERR.puts "missions with height of #{height}"
    visualize global_x, missions_y, [missions_resolution, missions_w], missions_rectangles, missions_data, height, missions_y_axis, resolutions_legend
  else
    STDERR.puts "minerals with height of #{height}"
    visualize global_x, minerals_y, [], minerals_rectangles, minerals_data, height, minerals_y_axis
  end
end

puts vis.generate_spec(:pretty)

# vis = visualization.width(WIDTH).height(HEIGHT) do
#   padding top: 10, left: 140, bottom: 30, right: 200
#   data missions_data, mineral_data #, minima_data
#   scales global_x, missions_y, minerals_y, missions_resolution, missions_w
#   marks missions_rectangles, minerals_rectangles
#   legends resolutions_legend
#   axes x_axis.scale(global_x).values([100,300,600,900,1700,2500,5000]).with_grid.layer(:back),
#        y_axis.scale(missions_y),
#        y_axis.scale(minerals_y)
# end



