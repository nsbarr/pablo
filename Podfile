# Uncomment this line to define a global platform for your project
# platform :ios, '8.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'ifeellikepablo' do
	pod 'Firebase/Core'
	pod 'Firebase/Storage'
	pod 'Firebase/Database'
	pod 'Koloda'
	pod 'Changeset', :git => 'https://github.com/osteslag/Changeset', :commit => '71aa5e8569b2b5133fab6d678bfa17d8c29eec6b'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end

