rm -rf perf/results
mkdir perf/results
CPUPROFILE_REALTIME=1 CPUPROFILE_FREQUENCY=1000 bundle exec ruby perf/profile.rb
