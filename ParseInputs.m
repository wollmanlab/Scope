function token = ParseInputs(TokenName, DefaultValue, Inputs)

if ~isempty(Inputs),
    j1=find(strcmp(Inputs, TokenName));
    if length(j1)>1,
        error(['Too many ' TokenName ' inputs!'])
    elseif length(j1)==1,
        token = Inputs{j1+1};
    else %default
        token = DefaultValue;
    end;
else
    token = DefaultValue;
end