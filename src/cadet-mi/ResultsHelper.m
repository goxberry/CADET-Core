
classdef ResultsHelper
	%ResultsHelper Helper class for extracting CADET results and postprocessing them
	%   Extracts data from the Matlab struct generated by CADET (either via MEX or
	%   from a read in HDF5 file) and converts them into a standardized structure.

	% Copyright: (C) 2008-2019 The CADET Authors
	%            See the license note at the end of the file.

	methods (Static)

		function out = extract(res, numUnitOperations)
			%EXTRACT Extracts and postprocesses results from a CADET run
			%   OUT = EXTRACT(RES, NUMUNITOPERATIONS) Converts the results given in RES to a
			%   standardized format, potentially converting storage ordering from row-major
			%   to column-major (Matlab). The output format is a struct that separates solution
			%   from sensitivity data and basically consists of cell arrays. There is one cell
			%   for each unit operation regardless of data for this unit operation is available.
			%   NUMUNITOPERATIONS is the number of unit operations in the system (which cannot
			%   be inferred from RES since data might be missing).
			%   Sensitivity fields have the same dimensions / sizes as the normal ones except
			%   for an additional dimension at the end of the array, which gives the parameter.
			%   For instance, the jacobian (sensitivity at column outlet) has the size
			%   [nTimePoints, nComponents, nParameters].

			if isfield(res, 'output')
				res = res.output;
			end

			% Determine number of unit operations
			maxUnit = 0;
			maxUnitSens = 0;
			maxParams = 0;
			if isfield(res, 'solution')
				maxUnit = max(cellfun(@(x) max([-1, sscanf(x, 'unit_%d')]), fieldnames(res.solution))) + 1;
			end
			if isfield(res, 'sensitivity')
				maxParams = max(cellfun(@(x) max([-1, sscanf(x, 'param_%d')]), fieldnames(res.sensitivity))) + 1;
				if isfield(res.sensitivity, sprintf('param_%03d', maxParams-1))
					maxUnitSens = max(cellfun(@(x) max([-1, sscanf(x, 'unit_%d')]), fieldnames(res.sensitivity.(sprintf('param_%03d', maxParams-1))))) + 1;
				end
			end

			if (maxUnit == 0) && ((nargin > 1) && ~isempty(numUnitOperations))
				maxUnit = numUnitOperations;
			end
			if (maxUnitSens == 0) && ((nargin > 1) && ~isempty(numUnitOperations))
				maxUnitSens = numUnitOperations;
			end

			maxReturnUnit = max(numUnitOperations, maxUnit);

			out.solution = [];
			out.solution.time = [];
			out.solution.outlet = cell(maxReturnUnit, 1);
			out.solution.outletDot = cell(maxReturnUnit, 1);
			out.solution.inlet = cell(maxReturnUnit, 1);
			out.solution.inletDot = cell(maxReturnUnit, 1);
			
			out.solution.bulk = cell(maxReturnUnit, 1);
			out.solution.bulkDot = cell(maxReturnUnit, 1);
			out.solution.particle = cell(maxReturnUnit, 1);
			out.solution.particleDot = cell(maxReturnUnit, 1);
			out.solution.solid = cell(maxReturnUnit, 1);
			out.solution.solidDot = cell(maxReturnUnit, 1);
			out.solution.flux = cell(maxReturnUnit, 1);
			out.solution.fluxDot = cell(maxReturnUnit, 1);
			out.solution.volume = cell(maxReturnUnit, 1);
			out.solution.volumeDot = cell(maxReturnUnit, 1);
			out.solution.lastState = [];
			out.solution.lastStateDot = [];

			if isfield(res, 'LAST_STATE_Y')
				out.solution.lastState = res.LAST_STATE_Y;
			end
			if isfield(res, 'LAST_STATE_YDOT')
				out.solution.lastStateDot = res.LAST_STATE_YDOT;
			end

			if isfield(res, 'solution')

				if isfield(res.solution, 'SOLUTION_TIMES')
					out.solution.time = res.solution.SOLUTION_TIMES;
				end

				for i = 1:maxUnit
					if ~isfield(res.solution, sprintf('unit_%03d', i-1))
						continue;
					end
					curRes = res.solution.(sprintf('unit_%03d', i-1));

					if isfield(curRes, 'SOLUTION_OUTLET')
						out.solution.outlet{i} = switchStorageOrdering(curRes.SOLUTION_OUTLET);
					end

					if isfield(curRes, 'SOLUTION_INLET')
						out.solution.inlet{i} = switchStorageOrdering(curRes.SOLUTION_INLET);
					end

					if isfield(curRes, 'SOLDOT_OUTLET')
						out.solution.outletDot{i} = switchStorageOrdering(curRes.SOLDOT_OUTLET);
					end

					if isfield(curRes, 'SOLDOT_INLET')
						out.solution.inletDot{i} = switchStorageOrdering(curRes.SOLDOT_INLET);
					end

					if isfield(curRes, 'SOLUTION_BULK')
						out.solution.bulk{i} = switchStorageOrdering(curRes.SOLUTION_BULK);
					end

					if isfield(curRes, 'SOLUTION_PARTICLE')
						out.solution.particle{i} = {switchStorageOrdering(curRes.SOLUTION_PARTICLE)};
					elseif isfield(curRes, 'SOLUTION_PARTICLE_PARTYPE_000')
						idxParType = 0;
						fieldParType = sprintf('SOLUTION_PARTICLE_PARTYPE_%03d', idxParType);
						out.solution.particle{i} = cell(0, 0);
						while isfield(curRes, fieldParType)
							temp = out.solution.particle{i};
							temp{idxParType + 1} = switchStorageOrdering(curRes.(fieldParType));
							out.solution.particle{i} = temp;

							idxParType = idxParType + 1;
							fieldParType = sprintf('SOLUTION_PARTICLE_PARTYPE_%03d', idxParType);
						end
					end

					if isfield(curRes, 'SOLUTION_SOLID')
						out.solution.solid{i} = {switchStorageOrdering(curRes.SOLUTION_SOLID)};
					elseif isfield(curRes, 'SOLUTION_SOLID_PARTYPE_000')
						idxParType = 0;
						fieldParType = sprintf('SOLUTION_SOLID_PARTYPE_%03d', idxParType);
						out.solution.solid{i} = cell(0, 0);
						while isfield(curRes, fieldParType)
							temp = out.solution.solid{i};
							temp{idxParType + 1} = switchStorageOrdering(curRes.(fieldParType));
							out.solution.solid{i} = temp;

							idxParType = idxParType + 1;
							fieldParType = sprintf('SOLUTION_SOLID_PARTYPE_%03d', idxParType);
						end
					end

					if isfield(curRes, 'SOLUTION_FLUX')
						out.solution.flux{i} = switchStorageOrdering(curRes.SOLUTION_FLUX);
					end

					if isfield(curRes, 'SOLUTION_VOLUME')
						out.solution.volume{i} = switchStorageOrdering(curRes.SOLUTION_VOLUME);
					end

					if isfield(curRes, 'SOLDOT_BULK')
						out.solution.bulkDot{i} = switchStorageOrdering(curRes.SOLDOT_BULK);
					end

					if isfield(curRes, 'SOLDOT_PARTICLE')
						out.solution.particleDot{i} = {switchStorageOrdering(curRes.SOLDOT_PARTICLE)};
					elseif isfield(curRes, 'SOLDOT_PARTICLE_PARTYPE_000')
						idxParType = 0;
						fieldParType = sprintf('SOLDOT_PARTICLE_PARTYPE_%03d', idxParType);
						out.solution.particleDot{i} = cell(0, 0);
						while isfield(curRes, fieldParType)
							temp = out.solution.particleDot{i};
							temp{idxParType + 1} = switchStorageOrdering(curRes.(fieldParType));
							out.solution.particleDot{i} = temp;

							idxParType = idxParType + 1;
							fieldParType = sprintf('SOLDOT_PARTICLE_PARTYPE_%03d', idxParType);
						end
					end

					if isfield(curRes, 'SOLDOT_SOLID')
						out.solution.solidDot{i} = {switchStorageOrdering(curRes.SOLDOT_SOLID)};
					elseif isfield(curRes, 'SOLDOT_SOLID_PARTYPE_000')
						idxParType = 0;
						fieldParType = sprintf('SOLDOT_SOLID_PARTYPE_%03d', idxParType);
						out.solution.solidDot{i} = cell(0, 0);
						while isfield(curRes, fieldParType)
							temp = out.solution.solidDot{i};
							temp{idxParType + 1} = switchStorageOrdering(curRes.(fieldParType));
							out.solution.solidDot{i} = temp;

							idxParType = idxParType + 1;
							fieldParType = sprintf('SOLDOT_SOLID_PARTYPE_%03d', idxParType);
						end
					end

					if isfield(curRes, 'SOLDOT_FLUX')
						out.solution.fluxDot{i} = switchStorageOrdering(curRes.SOLDOT_FLUX);
					end

					if isfield(curRes, 'SOLDOT_VOLUME')
						out.solution.volumeDot{i} = switchStorageOrdering(curRes.SOLDOT_VOLUME);
					end

					solNames = fieldnames(curRes);

					% Extract multi field data
					if isempty(out.solution.outlet{i})
						out.solution.outlet{i} = MultiFields.extract(curRes, solNames, 'SOLUTION_OUTLET_COMP');
					end
					if isempty(out.solution.outletDot{i})
						out.solution.outletDot{i} = MultiFields.extract(curRes, solNames, 'SOLDOT_OUTLET_COMP');
					end

					if isempty(out.solution.inlet{i})
						out.solution.inlet{i} = MultiFields.extract(curRes, solNames, 'SOLUTION_INLET_COMP');
					end
					if isempty(out.solution.inletDot{i})
						out.solution.inletDot{i} = MultiFields.extract(curRes, solNames, 'SOLDOT_INLET_COMP');
					end
				end

			end

			maxReturnUnitSens = max(numUnitOperations, maxUnitSens);

			out.sensitivity = [];
			out.sensitivity.jacobian = cell(maxReturnUnitSens, 1);
			out.sensitivity.jacobianDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.inlet = cell(maxReturnUnitSens, 1);
			out.sensitivity.inletDot = cell(maxReturnUnitSens, 1);

			out.sensitivity.bulk = cell(maxReturnUnitSens, 1);
			out.sensitivity.bulkDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.particle = cell(maxReturnUnitSens, 1);
			out.sensitivity.particleDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.solid = cell(maxReturnUnitSens, 1);
			out.sensitivity.solidDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.flux = cell(maxReturnUnitSens, 1);
			out.sensitivity.fluxDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.volume = cell(maxReturnUnitSens, 1);
			out.sensitivity.volumeDot = cell(maxReturnUnitSens, 1);
			out.sensitivity.lastState = [];
			out.sensitivity.lastStateDot = [];

			if isfield(res, 'LAST_STATE_SENSY_000')
				solNames = fieldnames(res);
				out.sensitivity.lastState = MultiFields.extract(res, solNames, 'LAST_STATE_SENSY');
			end

			if isfield(res, 'LAST_STATE_SENSYDOT_000')
				solNames = fieldnames(res);
				out.sensitivity.lastStateDot = MultiFields.extract(res, solNames, 'LAST_STATE_SENSYDOT');
			end

			if ~isfield(res, 'sensitivity') || (maxParams == 0)
				return;
			end

			for i = 1:maxUnitSens
				if ~isfield(res.sensitivity.(sprintf('param_%03d', maxParams-1)), sprintf('unit_%03d', i-1))
					continue;
				end
				curUnit = res.sensitivity.(sprintf('param_%03d', maxParams-1)).(sprintf('unit_%03d', i-1));

				if isfield(curUnit, 'SENS_OUTLET')
					data = zeros([size(curUnit.SENS_OUTLET), maxParams]);
					stride = numel(curUnit.SENS_OUTLET);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_OUTLET);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.jacobian{i} = data;
				end

				if isfield(curUnit, 'SENS_INLET')
					data = zeros([size(curUnit.SENS_INLET), maxParams]);
					stride = numel(curUnit.SENS_INLET);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_INLET);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.inlet{i} = data;
				end

				if isfield(curUnit, 'SENSDOT_OUTLET')
					data = zeros([size(curUnit.SENSDOT_OUTLET), maxParams]);
					stride = numel(curUnit.SENSDOT_OUTLET);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_OUTLET);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.jacobianDot{i} = data;
				end

				if isfield(curUnit, 'SENSDOT_INLET')
					data = zeros([size(curUnit.SENSDOT_INLET), maxParams]);
					stride = numel(curUnit.SENSDOT_INLET);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_INLET);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.inletDot{i} = data;
				end

				if isfield(curUnit, 'SENS_BULK')
					data = zeros([size(curUnit.SENS_BULK), maxParams]);
					stride = numel(curUnit.SENS_BULK);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_BULK);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.bulk{i} = data;
				end

				if isfield(curUnit, 'SENS_PARTICLE')
					data = zeros([size(curUnit.SENS_PARTICLE), maxParams]);
					stride = numel(curUnit.SENS_PARTICLE);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_PARTICLE);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.particle{i} = {data};
				elseif isfield(curUnit, 'SENS_PARTICLE_PARTYPE_000')
					idxParType = 0;
					fieldParType = sprintf('SENS_PARTICLE_PARTYPE_%03d', idxParType);
					out.sensitivity.particle{i} = cell(0, 0);
					while isfield(curUnit, fieldParType)
						data = zeros([size(curUnit.(fieldParType)), maxParams]);
						stride = numel(curUnit.(fieldParType));
						for p = 1:maxParams
							if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
								continue;
							end

							curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
							temp = switchStorageOrdering(curRes.(fieldParType));
							data((p-1)*stride+1:p*stride) = temp(:);
						end
						temp = out.sensitivity.particle{i};
						temp{idxParType + 1} = data;
						out.sensitivity.particle{i} = temp;

						idxParType = idxParType + 1;
						fieldParType = sprintf('SENS_PARTICLE_PARTYPE_%03d', idxParType);
					end
				end

				if isfield(curUnit, 'SENS_SOLID')
					data = zeros([size(curUnit.SENS_SOLID), maxParams]);
					stride = numel(curUnit.SENS_SOLID);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_SOLID);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.solid{i} = data;
				elseif isfield(curUnit, 'SENS_SOLID_PARTYPE_000')
					idxParType = 0;
					fieldParType = sprintf('SENS_SOLID_PARTYPE_%03d', idxParType);
					out.sensitivity.solid{i} = cell(0, 0);
					while isfield(curUnit, fieldParType)
						data = zeros([size(curUnit.(fieldParType)), maxParams]);
						stride = numel(curUnit.(fieldParType));
						for p = 1:maxParams
							if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
								continue;
							end

							curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
							temp = switchStorageOrdering(curRes.(fieldParType));
							data((p-1)*stride+1:p*stride) = temp(:);
						end
						temp = out.sensitivity.solid{i};
						temp{idxParType + 1} = data;
						out.sensitivity.solid{i} = temp;

						idxParType = idxParType + 1;
						fieldParType = sprintf('SENS_SOLID_PARTYPE_%03d', idxParType);
					end
				end

				if isfield(curUnit, 'SENS_FLUX')
					data = zeros([size(curUnit.SENS_FLUX), maxParams]);
					stride = numel(curUnit.SENS_FLUX);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_FLUX);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.flux{i} = data;
				end

				if isfield(curUnit, 'SENS_VOLUME')
					data = zeros([size(curUnit.SENS_VOLUME), maxParams]);
					stride = numel(curUnit.SENS_VOLUME);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENS_VOLUME);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.volume{i} = data;
				end

				if isfield(curUnit, 'SENSDOT_BULK')
					data = zeros([size(curUnit.SENSDOT_BULK), maxParams]);
					stride = numel(curUnit.SENSDOT_BULK);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_BULK);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.bulkDot{i} = data;
				end

				if isfield(curUnit, 'SENSDOT_PARTICLE')
					data = zeros([size(curUnit.SENSDOT_PARTICLE), maxParams]);
					stride = numel(curUnit.SENSDOT_PARTICLE);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_PARTICLE);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.particleDot{i} = data;
				elseif isfield(curUnit, 'SENSDOT_PARTICLE_PARTYPE_000')
					idxParType = 0;
					fieldParType = sprintf('SENSDOT_PARTICLE_PARTYPE_%03d', idxParType);
					out.sensitivity.particleDot{i} = cell(0, 0);
					while isfield(curUnit, fieldParType)
						data = zeros([size(curUnit.(fieldParType)), maxParams]);
						stride = numel(curUnit.(fieldParType));
						for p = 1:maxParams
							if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
								continue;
							end

							curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
							temp = switchStorageOrdering(curRes.(fieldParType));
							data((p-1)*stride+1:p*stride) = temp(:);
						end
						temp = out.sensitivity.particleDot{i};
						temp{idxParType + 1} = data;
						out.sensitivity.particleDot{i} = temp;

						idxParType = idxParType + 1;
						fieldParType = sprintf('SENSDOT_PARTICLE_PARTYPE_%03d', idxParType);
					end
				end

				if isfield(curUnit, 'SENSDOT_SOLID')
					data = zeros([size(curUnit.SENSDOT_SOLID), maxParams]);
					stride = numel(curUnit.SENSDOT_SOLID);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_SOLID);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.solidDot{i} = data;
				elseif isfield(curUnit, 'SENSDOT_SOLID_PARTYPE_000')
					idxParType = 0;
					fieldParType = sprintf('SENSDOT_SOLID_PARTYPE_%03d', idxParType);
					out.sensitivity.solidDot{i} = cell(0, 0);
					while isfield(curUnit, fieldParType)
						data = zeros([size(curUnit.(fieldParType)), maxParams]);
						stride = numel(curUnit.(fieldParType));
						for p = 1:maxParams
							if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
								continue;
							end

							curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
							temp = switchStorageOrdering(curRes.(fieldParType));
							data((p-1)*stride+1:p*stride) = temp(:);
						end
						temp = out.sensitivity.solidDot{i};
						temp{idxParType + 1} = data;
						out.sensitivity.solidDot{i} = temp;

						idxParType = idxParType + 1;
						fieldParType = sprintf('SENSDOT_SOLID_PARTYPE_%03d', idxParType);
					end
				end

				if isfield(curUnit, 'SENSDOT_FLUX')
					data = zeros([size(curUnit.SENSDOT_FLUX), maxParams]);
					stride = numel(curUnit.SENSDOT_FLUX);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_FLUX);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.fluxDot{i} = data;
				end

				if isfield(curUnit, 'SENSDOT_VOLUME')
					data = zeros([size(curUnit.SENSDOT_VOLUME), maxParams]);
					stride = numel(curUnit.SENSDOT_VOLUME);
					for p = 1:maxParams
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = switchStorageOrdering(curRes.SENSDOT_VOLUME);
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.volumeDot{i} = data;
				end

				solNames = fieldnames(res.sensitivity.(sprintf('param_%03d', maxParams-1)).(sprintf('unit_%03d', i-1)));

				% Extract multi field data
				if isempty(out.sensitivity.jacobian{i})
					temp = MultiFields.extract(curUnit, solNames, 'SENS_OUTLET_COMP');
					
					data = zeros([size(temp), maxParams]);
					stride = numel(temp);
					data((maxParams-1)+1:maxParams*stride) = temp(:);
					
					for p = 1:maxParams-1
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = MultiFields.extract(curRes, solNames, 'SENS_OUTLET_COMP');
						data((p-1)*stride+1:p*stride) = temp(:);
					end
					out.sensitivity.jacobian{i} = data;
				end
				if isempty(out.sensitivity.jacobianDot{i})
					temp = MultiFields.extract(curUnit, solNames, 'SENSDOT_OUTLET_COMP');

					data = zeros([size(temp), maxParams]);
					stride = numel(temp);
					data((maxParams-1)+1:maxParams*stride) = temp(:);

					for p = 1:maxParams-1
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = MultiFields.extract(curRes, solNames, 'SENSDOT_OUTLET_COMP');
						data((p-1)*stride+1:p*stride) = temp(:);					
					end
					out.sensitivity.jacobianDot{i} = data;
				end

				if isempty(out.sensitivity.inlet{i})
					temp = MultiFields.extract(curUnit, solNames, 'SENS_INLET_COMP');

					data = zeros([size(temp), maxParams]);
					stride = numel(temp);
					data((maxParams-1)+1:maxParams*stride) = temp(:);

					for p = 1:maxParams-1
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = MultiFields.extract(curRes, solNames, 'SENS_INLET_COMP');
						data((p-1)*stride+1:p*stride) = temp(:);					
					end
					out.sensitivity.inlet{i} = data;
				end
				if isempty(out.sensitivity.inletDot{i})
					temp = MultiFields.extract(curUnit, solNames, 'SENSDOT_INLET_COMP');

					data = zeros([size(temp), maxParams]);
					stride = numel(temp);
					data((maxParams-1)+1:maxParams*stride) = temp(:);

					for p = 1:maxParams-1
						if ~isfield(res.sensitivity, sprintf('param_%03d', p-1))
							continue;
						end

						curRes = res.sensitivity.(sprintf('param_%03d', p-1)).(sprintf('unit_%03d', i-1));
						temp = MultiFields.extract(curRes, solNames, 'SENSDOT_INLET_COMP');
						data((p-1)*stride+1:p*stride) = temp(:);					
					end
					out.sensitivity.inletDot{i} = data;
				end
			end
		end

	end
end

% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright (C) 2008-2019: The CADET Authors
%            Please see the AUTHORS and CONTRIBUTORS file.
%  
%  All rights reserved. This program and the accompanying materials
%  are made available under the terms of the GNU Public License v3.0 (or, at
%  your option, any later version) which accompanies this distribution, and
%  is available at http://www.gnu.org/licenses/gpl.html
% =============================================================================
