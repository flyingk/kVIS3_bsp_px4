% Script for comparing the values given by each import method
root_directory = 'C:\Users\matt\Documents\kVIS\kVIS3_bsp_px4\Sample_Data';
file = fullfile(root_directory,'log_0_2019-9-13-16-25-54.ulg');

% Import ulog File (using each type)
a = ulg_import_csv(file);                  a = remove_padding(a);
b = ulg_import(file);    b = getStruct(b); b = remove_padding(b);

% Print the log name we're missing (if we're missing any)
fprintf('fields(a): %d, fields(b): %d\n', numel(fieldnames(a.logs)), numel(fieldnames(b.logs)));
if (numel(fieldnames(a.logs)) ~= numel(fieldnames(b.logs)))
    fields = fieldnames(a.logs);
    for jj = 1:numel(fields)
        if ~isfield(b.logs,fields{jj})
            fprintf('\tMissing log: %s\n',fields{jj})
        end
    end
end


% Plot the results
fields = fieldnames(a.logs);
for jj = 1:numel(fields)
    % Dataset 1
    field_struct_1 = a.logs.(fields{jj});
    channels_1 = fieldnames(field_struct_1);
    num_channels = numel(channels_1);
    plot_h = ceil(sqrt(num_channels));
    plot_w = ceil((num_channels)/plot_h);
    t1 = field_struct_1.(channels_1{1})/1e6;
    
    % Dataset 2
    field_struct_2 = b.logs.(fields{jj});
    channels_2 = fieldnames(field_struct_2);
    t2 = field_struct_2.(channels_2{1})/1e6;
    
    % Plots
    figure(jj); clf; set(gcf,'name',fields{jj});
    set(gcf,'units','normalized');
    set(gcf,'outerposition',[0 0 1 1]);
    for kk = 2:num_channels
        subplot(plot_h,plot_w,kk-1); hold all; ...
            plot(t1,field_struct_1.(channels_1{kk}),'lineWidth',2); ...
            plot(t2,field_struct_2.(channels_2{kk}));
            title([channels_1{kk},' | ',channels_2{kk}],'interpreter','none');  
    end
end
    
    
