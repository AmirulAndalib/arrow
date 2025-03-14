// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#pragma once

#include <string_view>
#include <vector>

#include "arrow/compute/exec.h"
#include "arrow/type_fwd.h"

namespace arrow::compute {

using compute::ExecBatch;

ExecBatch ExecBatchFromJSON(const std::vector<TypeHolder>& types, std::string_view json);

/// \brief Shape qualifier for value types. In certain instances
/// (e.g. "map_lookup" kernel), an argument may only be a scalar, where in
/// other kernels arguments can be arrays or scalars
enum class ArgShape { ANY, ARRAY, SCALAR };

ExecBatch ExecBatchFromJSON(const std::vector<TypeHolder>& types,
                            const std::vector<ArgShape>& shapes, std::string_view json);

void ValidateOutput(const Datum& output);

}  // namespace arrow::compute
