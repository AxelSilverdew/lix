rl_next_generated = custom_target(
  command : [
    'bash',
    '-c',
    '''
      if type -p build-release-notes > /dev/null; then
        build-release-notes @CURRENT_SOURCE_DIR@
      fi
      @0@ @INPUT0@ @CURRENT_SOURCE_DIR@ > @DEPFILE@
    '''.format(
      python.full_path(),
    ),
  ],
  input : [
    generate_manual_deps,
  ],
  output : 'rl-next-generated.md',
  capture : true,
  depfile : 'rl-next.d',
)
