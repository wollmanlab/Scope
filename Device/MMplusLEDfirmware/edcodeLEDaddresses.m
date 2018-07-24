function intValue = edcodeLEDaddresses(address)

LED=false(1,256);
LED(address+1)=true;
conv=2.^(0:15);
intValue=zeros(1,16); 
for i=1:16, 
    intValue(i)=sum(LED((i-1)*16+(1:16)).*conv); 
end

