function rf_style_axes(ax,cfg)
set(ax,'FontName',cfg.fontName,'FontSize',cfg.fontSize, ...
    'LineWidth',cfg.axisLineWidth,'Box','off','TickDir','out', ...
    'Layer','top');
ax.XGrid = 'off';
ax.YGrid = 'off';
end
