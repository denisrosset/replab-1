classdef IsoDec < replab.rep.Dec
% Isotypic decomposition of the natural action of a generalized permutation group
%
% The change of basis matrix is adapted to the orbits of the group
    
    properties (SetAccess = immutable)
        algebra;      % Associative algebra which we decompose
        fromBlock;    % fromBlock(i) is the index of block in
                      % algebra.partition from which
                      % the basis vector U(:,i) comes from
        U;            % Orthonormal change of basis matrix
        ordered;      % Whether the representations inside the isotypic components have already been ordered
                      % so that an element of the group algebra is block-diagonal in the isotypic component basis
                      % with m copies of size d x d, where m is the multiplicity and d the dimension
                      % However, this ordering does not mean that equivalent representations are expressed in the
                      % same basis, or that real/complex/quaternionic representations are recognized: that is the
                      % job of IrrDec.
        nComponents;  % Number of isotypic components
        compDims;     % Isotypic component dimensions
        repDims;      % Representation (real) dimensions
        repMuls;      % Representation (real) multiplicities
    end
    
    methods
        
        function self = IsoDec(algebra, fromBlock, U, ordered, repDims, repMuls)
        % Constructs an IsoDec from full data
            assert(isreal(U));
            self.algebra = algebra;
            self.fromBlock = fromBlock;
            self.U = U;
            self.ordered = ordered;
            self.nComponents = length(repDims);
            self.repDims = repDims(:)';
            self.repMuls = repMuls(:)';
            self.compDims = repDims(:)' .* repMuls(:)';
            % TODO
            %if settings.checkLevel > 0
            %    self.check;
            %end
        end
        
        function R = compRange(self, r)
        % Indices corresponding to the r-th isotypic component
        % Correspond to columns of U, and to indices in fromBlock
            from = sum(self.compDims(1:r-1)) + 1;
            to = sum(self.compDims(1:r));
            R = from:to;
        end
        
        function Urep = compBasis(self, r)
        % Returns the basis of the r-th isotypic component
            Urep = self.U(:, self.compRange(r));
        end
        
        function refinedBasis = refinedBasis(self, r)
        % Returns the refined basis elements for the r-th representation
            range = self.compRange(r); % basis indices
            blocks = self.fromBlock(range); % blocks present in that component
            n = self.group.n;
            refinedBasis = zeros(n, length(range));
            for b = unique(blocks) % refine blocks individually
                basisInd = range(blocks == b); % basis elements we refine
                n = length(basisInd);
                % the b-th block elements
                bBlock = self.partition.block(b);
                % find restriction of group to the b-th block
                resPC = self.phaseConfiguration.restrict(bBlock);
                % basis for the r-th representation in the b-th block
                basis = self.U(bBlock, basisInd);
                % compute a sample
                T = basis*replab.rep.Random.symmetricGaussian(n)*basis'; % range in the corresponding representation
                T = resPC.project(T); % project in the invariant subspace
                                                            % compute eigenvalues, the n largest eigenvalues correspond to the representation basis
                T = T + T'; % force symmetry
                [U, ~] = replab.rep.sortedEig(T, 'descend', true);
                assert(isreal(U));
                refinedBasis(bBlock, blocks == b) = U(:, 1:n); % replace basis cutting the possible additional eigenvectors
            end
        end
        
        function I = refine(self)
        % Refine the change of basis by performing a second step of eigenvalue decomposition inside each
        % isotypic component. As a bonus, it orders the irreducible representations inside the isotypic
        % components, so that I.ordered = true.
            U = self.U;
            for r = 1:self.nComponents % refine each isotypic component
                range = self.compRange(r);
                U(:, range) = self.refinedBasis(r);
            end
            I = replab.rep.IsoDec(self.algebra, self.fromBlock, U, true, self.repDims, self.repMuls);
        end
        
        function b = smallestOrbitInRep(self, r)
        % Returns the smallest orbit present in the r-th representation
            range = self.compRange(r);
            % need only to consider one orbit
            blocks = self.fromBlock(range);
            B = unique(blocks(:));
            % Compute number of elements in the orbit
            B = [arrayfun(@(b) sum(blocks == b), B) B];
            B = sortrows(B);
            b = B(1, 2);
        end
        
        function r = repIsReal(self, r)
        % Returns whether the r-th representation is real
            import qdimsum.*
            % Eigenvalue tolerance
            tol = self.settings.blockDiagEigTol;
            % Find smallest group orbit to perform the test in
            o = self.smallestOrbitInRep(r);
            range = self.compRange(r);
            % Full orbit, can include other representations, used to select the
            % phase configuration to be sampled
            fullOrbit = self.group.permOrbits.orbits{o};
            % Representation basis vectors corresponding to that orbit
            repOrbit = range(self.fromOrbit(range) == o);
            Urep = self.U(fullOrbit, repOrbit);
            % Group restriction to the selected orbit
            resGroup = self.group.permOrbitRestriction(o);
            % Compute sample, transform in the representation space
            sampleGen = Urep'*resGroup.phaseConfiguration.sampleRealGaussian*Urep;
            sampleSym = sampleGen + sampleGen';
            % Compute eigenvalues of both the nonsymmetric and the made-symmetric matrix
            lambdaGen = eig(sampleGen);
            lambdaSym = eig(sampleSym);
            % Compute eigenvalues that are close
            distGen = abs(bsxfun(@minus, lambdaGen, lambdaGen.'));
            distSym = abs(bsxfun(@minus, lambdaSym, lambdaSym.'));
            maskGen = distGen <= tol;
            maskSym = distSym <= tol;
            % Histogram update to check precision
            if ~isequal(self.settings.blockDiagEigHist, [])
                self.settings.blockDiagEigHist.register(distGen(maskGen));
                self.settings.blockDiagEigHist.register(distSym(maskSym));
            end
            % Connect close eigenvalues
            conGen = findConnectedComponents(maskGen);
            conSym = findConnectedComponents(maskSym);
            lenGen = cellfun(@(x) length(x), conGen);
            lenSym = cellfun(@(x) length(x), conSym);
            assert(all(lenGen == lenGen(1)));
            assert(all(lenSym == lenSym(1)));
            % Same number of distinct eigenvalues between nonsym and sym? Then the representation is real
            r = length(conGen) == length(conSym);
        end
        
% $$$         function blocks = projectInIsoBasis(self, M)
% $$$             blocks = cell(1, self.nComponents);
% $$$             for r = 1:self.nComponents
% $$$                 range = self.compRange(r);
% $$$                 blocks{r} = self.U(:, range)' * M * self.U(:, range);
% $$$             end
% $$$         end

% $$$         function check(self)
% $$$         % Checks the validity of this isotypic decomposition
% $$$             import qdimsum.*
% $$$             tol = self.settings.blockDiagMatTol;
% $$$             % Checks that the isotypic components are correct by considering
% $$$             % a sample from matrices that commute with the group
% $$$             sample = self.group.phaseConfiguration.sampleRealGaussian;
% $$$             sample = self.U'*sample*self.U;
% $$$             for i = 1:self.nComponents
% $$$                 ir = self.compRange(i);
% $$$                 for j = 1:self.nComponents
% $$$                     jr = self.compRange(j);
% $$$                     block = sample(ir, jr);
% $$$                     assert(isNonZeroMatrix(block, tol) == (i == j));
% $$$                 end
% $$$             end
% $$$             % Second check by using sampling from the group algebra
% $$$             M1 = self.U'*GenPerm.orthogonalMatrix(self.group.randomElement)*self.U;
% $$$             M2 = self.U'*GenPerm.orthogonalMatrix(self.group.randomElement)*self.U;
% $$$             M = randn * M1 + randn * M2;
% $$$             for i = 1:self.nComponents
% $$$                 ir = self.compRange(i);
% $$$                 for j = 1:self.nComponents
% $$$                     jr = self.compRange(j);
% $$$                     % standard check
% $$$                     block = M(ir, jr);
% $$$                     assert(isNonZeroMatrix(block, tol) == (i == j));
% $$$                     if i == j && self.ordered
% $$$                         % verify that irreducible representations are grouped correctly inside the
% $$$                         % isotypic component
% $$$                         m = self.repMuls(i);
% $$$                         d = self.repDims(i);
% $$$                         for k = 1:m
% $$$                             kr = d*(k-1) + (1:d);
% $$$                             for l = 1:m
% $$$                                 lr = d*(l-1) + (1:d);
% $$$                                 assert(isNonZeroMatrix(block(kr, lr), tol) == (k == l));
% $$$                             end
% $$$                         end 
% $$$                     end
% $$$                 end
% $$$             end
% $$$         end
        
    end

    methods (Static)
       
        function I = forAlgebra(algebra)
        % Computes the isotypic decomposition of the given algebra
            tol = replab.Settings.eigTol('R15');
            % Get problem structure
            n = algebra.n;
            nBlocks = algebra.partition.nBlocks;
            % Get first sample
            sample1 = algebra.sampleSelfAdjoint;
            % Data to be prepared
            fromBlock = zeros(1, n);
            runs = {}; % identify indices of repeated eigenvalues
            U = zeros(n, n); % use dense matrix for now, but should switch to sparse
                             % if the savings due to blocks are worth it
            shift = 0;
            % Treat each block individually, to preserve some sparsity
            for b = 1:nBlocks
                block = algebra.partition.block(b); % indices in the current block
                blockSize = length(block);
                basisIndices = shift + (1:blockSize); % indices of basis elements to compute
                [Ub Db] = replab.rep.sortedEig(sample1(block, block), 'ascend', false);
                Db = diag(Db);
                Db = Db(:)';
                U(block, basisIndices) = Ub;
                fromBlock(basisIndices) = b;
                % find subspaces corresponding to repeated eigenvalues
                mask = bsxfun(@(x,y) abs(x-y)<tol, Db, Db');
                runsb = replab.Partition.connectedComponents(mask).blocks;
                % shift to cater to basis indices
                runsb = cellfun(@(r) r + shift, runsb, 'UniformOutput', false); 
                % concatenate runs
                runs = horzcat(runs, runsb); 
                shift = shift + blockSize;
            end
            % Now, U provides a basis that splits isotypic components. Remains to group them
            % according to their equivalent representations.
            sample2 = algebra.sampleSelfAdjoint;
            sample2p = U'*sample2*U;
            % We are computing the block mask, where each block corresponds to a run of identical
            % eigenvalues.
            % Blocks corresponding to inequivalent representations should be zero; to cater
            % for numerical errors, we check whether the matrix 2-norm is above or below
            % the tolerance 'blockDiagMatTol'.
            nRuns = length(runs);
            blockMask = logical(zeros(nRuns, nRuns));
            v = zeros(nRuns, nRuns);
            for i = 1:nRuns
                for j = 1:nRuns
                    block = sample2p(runs{i}, runs{j});
                    blockMask(i, j) = replab.rep.isNonZeroMatrix(block, tol);
                end
            end
            % find the subspaces corresponding to the same irreducible representation
            % by looking at the connected components of the graph defined by the adjacency
            % matrix of the block mask
            cc = replab.Partition.connectedComponents(blockMask).blocks;
            Nc = length(cc);
            reps = zeros(2, Nc);
            for i = 1:Nc
                c = cc{i};
                reps(2, i) = length(c);
                dims = arrayfun(@(i) length(runs{i}), c);
                % verify that the dimensions are all the same for consistency
                assert(all(dims - dims(1) == 0), 'Inconsistent representation dimensions');
                reps(1, i) = dims(1);
            end
            % sort the irreducible representations first by increasing dimension
            % then by increasing multiplicity
            [~, I] = sortrows(reps');
            reps = reps(:, I);
            cc = cc(I);
            reorder = cellfun(@(i) horzcat(runs{i}), cc, 'UniformOutput', false);
            reorder = [reorder{:}];
            U = U(:, reorder);
            fromBlock = fromBlock(reorder);
            I = replab.rep.IsoDec(algebra, fromBlock, U, true, reps(1, :), reps(2, :));
        end
        
    end
    
end