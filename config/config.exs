use Mix.Config

config :membrane_element_opus, :bundlex_lib,
  macosx: [
    nif: [
      membrane_element_opus_encoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
        ],
        pkg_configs: [
          "opus",
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
        ],
        pkg_configs: [
          "opus",
        ]
      ]
    ]
  ],
  windows32: [
    nif: [
      membrane_element_opus_encoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
        ]
      ]
    ]
  ],
  windows64: [
    nif: [
      membrane_element_opus_encoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
        ]
      ]
    ]
  ],
  linux: [
    nif: [
      membrane_element_opus_encoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
        ],
        pkg_configs: [
          "opus",
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
        ],
        pkg_configs: [
          "opus",
        ]
      ],
    ]
]
