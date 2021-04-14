% Script for comparing the speed of each of the import methods

% root_directory = uigetdir(pwd,'Import PX4 Folder');
root_directory = 'C:\Users\matt\Documents\kVIS\kVIS3_bsp_px4\Sample_Data';
files = dir([root_directory,'\**\*.ulg']);

% Import each file
tocs = nan(numel(files),3);

for ii = 1:numel(files)
    
    % Import ulog File
    file = fullfile(files(ii).folder,files(ii).name);
    tocs(ii,1) = files(ii).bytes/1024/1024;
    
    tic; a = ulg_import_csv(file);
    tocs(ii,2) = toc;
    
    tic; b = ulg_import(file); 
    tocs(ii,3) = toc;
    
    % Print the log name we're missing (if we're missing any)
    fprintf('fields(a): %d, fields(b): %d\n', ...
        numel(fieldnames(a.logs)), numel(fieldnames(b.logs)));
    if (numel(fieldnames(a.logs)) ~= numel(fieldnames(b.logs)))
        fields = fieldnames(a.logs);
        for jj = 1:numel(fields)
            if ~isfield(b.logs,fields{jj})
                fprintf('\tMissing log: %s\n',fields{jj})
                keyboard
            end
            
        end
    end
    
end

% Sort by file size
[~,idx] = sort(tocs(:,1));
tocs = tocs(idx,:);

%% Plot results
figure(1); clf; hold all; set(gcf,'name','Speed Comparison');
subplot(2,1,1); hold all; grid on; grid minor; title(sprintf('ulg Import Time: %d Samples',numel(files))); ...
    plot(tocs(:,1),tocs(:,2),'o--','displayName','csv Import'); ...
    plot(tocs(:,1),tocs(:,3),'o--','displayName','Direct Import'); ...
    xlabel('Size [ MiB ]'); ylabel('Processing Time [ s ]'); ...
    legend show; legend boxoff; legend('location','southEast');
subplot(2,1,2); hold all; grid on; grid minor; ...
    plot(tocs(:,1),tocs(:,3)./tocs(:,2),'o--','displayName','Direct/csv Import'); ...
    xlabel('Size [ MiB ]'); ylabel([{'Processing Time'},{'Normalised by CSV Import'}]); ...
    legend show; legend boxoff; legend('location','southEast'); ...
    
