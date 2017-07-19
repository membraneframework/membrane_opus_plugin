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
          "ext/include",
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
          "ext/windows/32/opus.lib",
          "ext/windows/32/celt.lib",
          "ext/windows/32/silk_common.lib",
          "ext/windows/32/silk_float.lib"
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
          "ext/include",
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
          "ext/windows/32/opus.lib",
          "ext/windows/32/celt.lib",
          "ext/windows/32/silk_common.lib",
          "ext/windows/32/silk_float.lib"
        ]
      ]
    ]
  ],
  windows64: [
    nif: [
      membrane_element_opus_encoder: [
        includes: [
	        "ext/include",
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "encoder.c",
        ],
        libs: [
          "ext/windows/64/opus.lib",
          "ext/windows/64/celt.lib",
          "ext/windows/64/silk_common.lib",
          "ext/windows/64/silk_float.lib"
        ]
      ],
      membrane_element_opus_decoder: [
        includes: [
	        "ext/include",
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "util.c",
          "decoder.c",
        ],
        libs: [
          "ext/windows/64/opus.lib",
          "ext/windows/64/celt.lib",
          "ext/windows/64/silk_common.lib",
          "ext/windows/64/silk_float.lib"
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
