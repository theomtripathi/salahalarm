require 'xcodeproj'
require 'fileutils'

project_path = '/Users/pc/Downloads/salahalarm/Ramadan Pro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Copy file
source_path = '/Users/pc/Documents/salahalarm/alarmsound/wake-up.mp3'
dest_dir = '/Users/pc/Downloads/salahalarm/Ramadan Pro/Resources'
dest_path = File.join(dest_dir, 'wake-up.mp3')

FileUtils.mkdir_p(dest_dir)
FileUtils.cp(source_path, dest_path)

# Find or create group
group = project.main_group.find_subpath('Ramadan Pro/Resources', true)

# Add to group if not exists
file_ref = group.files.find { |f| f.path == 'wake-up.mp3' }
if file_ref.nil?
  file_ref = group.new_reference(dest_path)
end

# Add to target's resources build phase
resources_phase = target.resources_build_phase
unless resources_phase.files_references.include?(file_ref)
  resources_phase.add_file_reference(file_ref, true)
end

project.save
puts "Added wake-up.mp3 to the Xcode project successfully."
