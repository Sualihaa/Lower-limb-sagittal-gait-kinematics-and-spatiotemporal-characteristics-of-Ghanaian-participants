function rf_export_figure(fig,outBase,widthMm,heightMm)
%RF_EXPORT_FIGURE Save editable and submission-ready figure formats.

if nargin < 4
    error('rf_export_figure requires fig, output base, widthMm and heightMm.');
end

outDir = fileparts(outBase);
if ~isfolder(outDir); mkdir(outDir); end

set(fig,'Color','w','Renderer','painters');
set(fig,'Units','centimeters');
set(fig,'Position',[1 1 widthMm/10 heightMm/10]);
set(fig,'PaperUnits','centimeters');
set(fig,'PaperPositionMode','manual');
set(fig,'PaperPosition',[0 0 widthMm/10 heightMm/10]);
set(fig,'PaperSize',[widthMm/10 heightMm/10]);

drawnow;

savefig(fig,[outBase '.fig']);
exportgraphics(fig,[outBase '.pdf'],'ContentType','vector','BackgroundColor','white');
exportgraphics(fig,[outBase '.svg'],'ContentType','vector','BackgroundColor','white');
exportgraphics(fig,[outBase '.png'],'Resolution',600,'BackgroundColor','white');
exportgraphics(fig,[outBase '.tif'],'Resolution',600,'BackgroundColor','white');
print(fig,[outBase '.eps'],'-depsc','-painters');
end
