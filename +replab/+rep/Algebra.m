classdef Algebra < replab.Str
% A n x n real matrix algebra
    
    properties (SetAccess = protected)
        fibers; % A fiber is a subset of the coordinates 1..n
                % such that { M(fiber, fiber) for M \in algebra }
                % is also an algebra, and fiber = 1..nF
                % The finest decomposition of 1..n into fibers
                % is stored as a replab.Partition into this variable
        n; % Size of the n x n matrix representation of this algebra
    end
    
    methods
        
        function A = restrictedToFibers(self, fibers)
        % Returns a restriction of this algebra to the given fibers,
        % where the fibers is an ordered subset of {1..nF}
            error('Not implemented');
        end
        
        function M = sample(self)
        % Samples a generic random element of this algebra
            error('Not implemented');
        end
        
        function M = sampleSelfAdjoint(self)
        % Samples a self-adjoint generic random element of this algebra
            error('Not implemented');
        end
        
        function M = project(self, T)
        % Projects the matrix T on this algebra
        %
        % TODO: define properly what orthogonality means in the
        % general context
            error('Not implemented');
        end
        
    end
    
    methods (Static)
       
        function A = forNonSignedPermRep(rep, matrices)
            error('TODO: not implemented.')
        end
        
        function A = forRep(rep)
            nG = rep.group.nGenerators;
            matrices = cell(1, nG);
            d = rep.dimension;
            for i = 1:nG
                matrices{i} = rep.image(rep.group.generator(i));
            end
            signedPerms = zeros(nG, d);
            for i = 1:nG
                sp = replab.SignedPermutations.fromMatrix(matrices{i});
                if isempty(sp)
                    A = replab.rep.Algebra.forNonSignedPermRep;
                    return
                end
                signedPerms(i,:) = sp;
            end
            phaseConfiguration = replab.rep.SignedConfigurationBuilder(signedPerms).toPhaseConfiguration;
            A = replab.rep.PhaseConfigurationAlgebra(phaseConfiguration, rep.fibers);
        end
        
    end
    
end
