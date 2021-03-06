# Benchmark definition file for HiBench2

[ ! "$BENCH_LIST" ] && BENCH_LIST="terasort wordcount sort kmeans pagerank bayes dfsioe nutchindexing hivebench"

# 1.) Load sources
# Load Hadoop and java functions and defaults
source_file "$ALOJA_REPO_PATH/shell/common/common_hadoop.sh"
set_hadoop_requires

# Load common benchmark functions
source_file "$ALOJA_REPO_PATH/shell/common/common_HiBench.sh"
set_HiBench_requires


benchmark_suite_config() {
  initialize_hadoop_vars
  initialize_HiBench_vars
  prepare_hadoop_config "$NET" "$DISK" "$BENCH_SUITE"
}

benchmark_suite_run() {
  execute_HiBench
}

benchmark_suite_save() {
  : # Empty
}

benchmark_suite_cleanup() {
  stop_hadoop
}

benchmark_hibench_config_bayes() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_dfsioe() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_kmeans() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_pagerank() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_sort() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_terasort() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_wordcount() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}

benchmark_hibench_config_hivebench() {
  export COMPRESS_GLOBAL=1
  export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
}