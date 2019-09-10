classdef FiniteGroup < replab.CompactGroup
    
    properties (SetAccess = protected)
        generators % row cell array of group elements: Group generators
        order % vpi: Order of the group, equal to the number of distinct group elements
    end
    
    properties (Access = protected)
        randomBag_ % replab.RandomBag: Bag of elements used for random sampling
        elements_ % replab.Enumerator: Cached enumerator of group elements
        decomposition_ % replab.FiniteGroupDecomposition: Cached decomposition of this group
    end
    
    methods % Abstract (and cached) methods

        function E = elements(self)
        % Returns an enumeration of the group elements
        %
        % Returns:
        %   replab.Enumerator: A space-efficient enumeration of the group elements
            if isempty(self.elements_)
                self.elements_ = self.computeElements;
            end
            E = self.elements_;
        end

        function E = computeElements(self)
        % Computes the result cached by self.elements
            error('Abstract');
        end
        
        function D = decomposition(self)
        % Returns a decomposition of this group as a product of sets
        %
        % Returns:
        %   replab.FiniteGroupDecomposition: The group decomposition
            if isempty(self.decomposition_)
                self.decomposition_ = self.computeDecomposition;
            end
            D = self.decomposition_;
        end

        function D = computeDecomposition(self)
        % Computes the result cached by self.decomposition
            error('Abstract');
        end

    end
    
    methods
        
        function R = randomBag(self)
            if isequal(self.randomBag_, [])
                self.randomBag_ = replab.RandomBag(self, self.generators);
            end
            R = self.randomBag_;
        end

        % Str
        
        function names = hiddenFields(self)
            names = hiddenFields@replab.Group(self);
            names{1, end+1} = 'generators';
        end
        
        function [names values] = additionalFields(self)
            [names values] = additionalFields@replab.Group(self);
            for i = 1:self.nGenerators
                names{1, end+1} = sprintf('generator(%d)', i);
                values{1, end+1} = self.generator(i);
            end
        end

        % Domain
        
        function g = sample(self)
            g = self.randomBag.sample;
        end
                
        % CompactGroup
        
        function g = sampleUniformly(self)
            g = self.elements.sample;
        end

        % Own methods
        
        function n = nGenerators(self)
        % Returns the number of group generators
        %
        % Returns:
        %   integer: Number of group generators
            n = length(self.generators);
        end
        
        function p = generator(self, i) 
        % Returns the i-th group generator
        %
        % Args:
        %   i (integer): Generator index
        %
        % Returns:
        %   element: i-th group generator
            p = self.generators{i};
        end
        
        function p = generatorInverse(self, i)
        % Returns the inverse of the i-th group generator
        %
        % Args:
        %   i (integer): Generator index
        %
        % Returns:
        %   element: Inverse of the i-th group generator
            p = self.inverse(self.generators{i});
        end

        function b = isTrivial(self)
        % Tests whether this group is trivial
        %
        % Returns:
        %   logical: True if this group is trivial (i.e. has only one element)
            b = self.nGenerators == 0;
        end

        function rep = leftRegularRep(self)
        % Returns the left regular representation of this group
        %
        % Warning:
        %   The choice of a basis for the regular representation is not deterministic,
        %   and results can vary between runs.
        %
        % Returns:
        %   replab.Rep: The left regular representation as a real permutation representation
            o = self.order;
            assert(o < 1e6);
            o = double(o);
            perms = cell(1, self.nGenerators);
            E = self.elements;
            for i = 1:self.nGenerators
                g = self.generator(i);
                img = zeros(1, o);
                for j = 1:o
                    img(j) = double(E.find(self.compose(g, E.at(j))));
                end
                perms{i} = img;
            end
            rep = self.permutationRep(o, perms);
        end

    end

end