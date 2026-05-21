# SmoreGSA

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://drbergman-lab.github.io/SmoreGSA.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://drbergman-lab.github.io/SmoreGSA.jl/dev/)
[![Build Status](https://github.com/drbergman-lab/SmoreGSA.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/drbergman-lab/SmoreGSA.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/drbergman-lab/SmoreGSA.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/drbergman-lab/SmoreGSA.jl)

SmoreGSA.jl is a Julia package that supports global sensitivity analysis (GSA) within the SMoRe framework. 
It implements the SMoRe GloS framework described in [**An efficient and flexible framework for inferring global sensitivity of agent-based model parameters**](https://doi.org/10.1371/journal.pcbi.1013427). It provides tools and methods for performing sensitivity analysis on surrogate models, allowing users to identify which input parameters have the most significant impact on the output of a model. This package includes various techniques for GSA, such as variance-based methods, Sobol indices, and other sensitivity measures. SmoreGSA.jl is designed to work seamlessly with the core functionalities provided by SmoreBase.jl, enabling users to easily integrate sensitivity analysis into their surrogate modeling workflows.