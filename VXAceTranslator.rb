require_relative 'Modules/RVData2Decompiler'
require_relative 'Modules/RVData2Compiler'
require_relative 'Modules/Utils'
require_relative 'Modules/RPG'
require_relative 'Modules/ModStack'
require 'optparse'
require 'zlib'

$test = false
$stdout.sync = true

USAGE = "#{RED_COLOR}Decompiler Usage: RPGMakerVXAceTranslator.rb -d GAME_DIR -o OUTPUT_DIR [Optional]
Compiler Usage: RPGMakerVXAceTranslator.rb -c GAME_DIR -i INPUT_DIR [--mod MOD_DIRECTORY ...] [Optional] -o OUTPUT_DIR [Optional]#{RESET_COLOR}"

options = {}
options[:target_basename] = ''
options[:input] = ''
options[:output] = ''
options[:indexless] = true
options[:force_decrypt] = false
options[:mods] = []
options[:dry_run] = false

while (arg = ARGV.shift)

  case arg
  when '-d', '--decompile'
    options[:decompile] = ARGV.shift
  when '-c', '--compile'
    options[:compile] = ARGV.shift
  when '-t', '--target'
    options[:target_basename] = ARGV.shift
  when '-i', '--input'
    options[:input] = ARGV.shift
  when '-o', '--output'
    options[:output] = ARGV.shift
  when '--switch-indexless'
    options[:indexless] = false
  when '--force-decrypt'
    options[:force_decrypt] = true
  when '--mod'
    options[:mods] << ARGV.shift
  when '--dry-run'
    options[:dry_run] = true
  when '-h', '--help'
    print USAGE
    $stdout.flush

    exit
  else
    print USAGE
    $stdout.flush

    exit
  end

end

unless options[:decompile] || options[:compile]
  puts USAGE
  exit
end

unless ENV["OCRA_EXECUTABLE"].nil?
  Dir.chdir(File.dirname(ENV["OCRA_EXECUTABLE"]))
end

if not options[:decompile].nil?
  d = RVData2Decompiler.new
  d.decompile(options[:decompile],
              output_path=options[:output],
              target_basename=options[:target_basename],
              indexless=options[:indexless],
              force_decrypt=options[:force_decrypt])


elsif not options[:compile].nil?
  if options[:mods].empty?
    c = RVData2Compiler.new
    c.compile(options[:compile],
              input_path=options[:input],
              output_path=options[:output],
              target_basename=options[:target_basename],
              indexless=options[:indexless],
              force_decrypt=options[:force_decrypt]) unless options[:dry_run]
  else
    raise ArgumentError, '--mod requires an explicit -i/--input translation directory' if options[:input].empty?

    stack = ModStack.new(options[:input], options[:mods])
    stack.with_staging_directory do |staging_directory|
      stack.conflicts.each do |conflict|
        puts "Mod override: #{conflict.relative_path} (#{conflict.previous_source} -> #{conflict.replacement_source})"
      end
      unless options[:dry_run]
        c = RVData2Compiler.new
        c.compile(options[:compile],
                  input_path=staging_directory,
                  output_path=options[:output],
                  target_basename=options[:target_basename],
                  indexless=options[:indexless],
                  force_decrypt=options[:force_decrypt])
      end
    end
  end


end
