function overlayLabels(Lbl, channel, idx, figureNum)
    type='cyto';
    MD = Metadata(Lbl.pth);
    name = Lbl.posname;
    T = MD.getSpecificMetadata('TimestampImage', 'Channel', channel, 'Position', Lbl.posname);
    T = cat(1, T{:});
    Tidx = T(idx);
    timefunc = @(x) ismember(x, Tidx);
    images = stkread(MD, 'Channel', channel, 'Position', name, 'timefunc', timefunc);
    i=1;
    img = images(:,:,i);
    figure(figureNum)
    subplot('position',[0 0 0.5 1])
    lbls = Lbl.getLbls('cyto');
    lbl = lbls(:,:, i);
    lblbw = lbl>0;
    lbl(lblbw)=1;
    lblrgb = lbl2rgb(lbl);
    imshowpair(lblrgb, imadjust(img))
    h(1)=gca; 
    subplot('position',[0.5 0 0.5 1])
    lbls = Lbl.getLbls('nuc');
    lbl = lbls(:,:, i);
    lblbw = lbl>0;
    lbl(lblbw)=1;
    lblrgb = lbl2rgb(lbl);
    figure(figureNum)
    imshowpair(lblrgb, imadjust(img))
    h(2)=gca;
    linkaxes(h)
end