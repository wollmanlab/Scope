function totSize = getSize(object)
    props = properties(object);
    totSize = 0;
    for ii=1:length(props)
        currentProperty = getfield(object, char(props(ii)));
        s = whos('currentProperty');
        totSize = totSize + s.bytes;
        
    end
    totSize = totSize*9.54e-7;
    fprintf(1, '%d Megabytes \n', round(totSize));
end
    