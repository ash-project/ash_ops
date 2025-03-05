spark_locals_without_parens = [
  arguments: 1,
  create: 3,
  create: 4,
  description: 1,
  destroy: 3,
  destroy: 4,
  get: 3,
  get: 4,
  list: 3,
  list: 4,
  prefix: 1,
  read_action: 1,
  update: 3,
  update: 4
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  import_deps: [:ash],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
