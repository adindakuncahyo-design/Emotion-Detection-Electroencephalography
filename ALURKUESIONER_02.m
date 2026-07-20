clear; clc; close all;

%% read file
filename = 'SHK002.xlsx';
disp(['Membaca file : ',filename]);

T = readtable(filename);

% Hilangkan kolom waktu jika ada
if ismember('Time',T.Properties.VariableNames)
    T.Time = [];
end

data = table2array(T);

channel_names = T.Properties.VariableNames;

fprintf('Jumlah Kanal : %d\n',size(data,2));
fprintf('Jumlah Sampel: %d\n',size(data,1));

fs = 400;

% VISUALISASI DATA 
figure('Name','Visualisasi Data',...
       'Position',[50 50 1300 700]);

spacing = max(std(data-mean(data,1))) * 8;

t = (0:size(data,1)-1)/fs;

plot(t,...
    (data-mean(data,1)) + (size(data,2):-1:1)*spacing,...
    'Color',[0 0 0.5]);

yticks((1:size(data,2))*spacing)
yticklabels(flip(channel_names))

xlabel('Waktu (s)')
ylabel('Kanal EEG')
title('Visualisasi Data')
grid on

xlim([0 5])

%simpan
savefig('Visualisasi Data.fig')

exportgraphics(gcf,...
    'Visualisasi Data.png',...
    'Resolution',300);

disp('Visualisasi berhasil disimpan.')

%% LABEL (BERDASARKAN KUESIONER)
disp('Melakukan Label Assignment...');

label = 1; % sesuai jawaban kuesioner, 0 = Negatif | 1 = Non-Negatif

if label == 0
    emosi = "Negatif";
else
    emosi = "Non-Negatif";
end

% Simpan ke Excel
tabel_label = table(...
    label,...
    emosi,...
    'VariableNames',{'Label','Emosi'});

writetable(tabel_label,'shk002_label.xlsx');

fprintf('Label : %d (%s)\n',label,emosi);

%% BANDPASS FILTER
disp('Menerapkan Butterworth Bandpass Filter (8-30 Hz)...');

low_cutoff = 8;      % Hz
high_cutoff = 30;    % Hz
filter_order = 4;

[b,a] = butter(filter_order,...
    [low_cutoff high_cutoff]/(fs/2),...
    'bandpass');

num_channels = size(data,2);

data_bandpass = zeros(size(data));

% Filtering setiap kanal
for c = 1:num_channels

    data_bandpass(:,c) = filtfilt(b,a,data(:,c));

end

disp('Filtering selesai.');

% simpan
tabel_bandpass = array2table(...
    data_bandpass,...
    'VariableNames',channel_names);

writetable(tabel_bandpass,...
    'shk002_bandpass.xlsx');

disp('File bandpass berhasil disimpan.');

% visualisasi
figure('Name','Perbandingan Raw vs Bandpass',...
    'Position',[100 60 1300 700]);

subplot(2,1,1)

spacing_raw = max(std(data-mean(data,1)))*8;

plot(t,...
    (data-mean(data,1))+...
    (num_channels:-1:1)*spacing_raw,...
    'b');

yticks((1:num_channels)*spacing_raw); yticklabels(flip(channel_names));
title(' '); xlabel('Waktu (detik)'); ylabel('Kanal'); xlim([0 5]);
grid on;

subplot(2,1,2)
spacing_bp = max(std(data_bandpass-mean(data_bandpass,1)))*8;

plot(t,...
    (data_bandpass-mean(data_bandpass,1))+...
    (num_channels:-1:1)*spacing_bp,...
    'Color',[0 0.45 0]);

yticks((1:num_channels)*spacing_bp); yticklabels(flip(channel_names));
title(' '); xlabel('Waktu (detik)'); ylabel('Kanal');
xlim([0 5]); grid on;

set(gcf,'Color','w');

saveas(gcf,'Visualisasi Raw vs Bandpass.png');

% visualisasi perwakilan
representative = {'Fp1_A1','Fp2_A2','F3_A1','F4_A2'};

figure('Name','Representative Channels',...
    'Position',[120 80 1200 900]);

for k = 1:length(representative)

    idx = find(strcmp(channel_names,representative{k}));

    subplot(length(representative),2,(k-1)*2+1)
    plot(t,data(:,idx),'b');
    title([representative{k} ' - Raw']);
    xlabel('Waktu (detik)'); ylabel('Amplitude'); xlim([0 5]);
    grid on;

    subplot(length(representative),2,(k-1)*2+2)
    plot(t,data_bandpass(:,idx),'r');
    title([representative{k} ' - Bandpass']);
    xlabel('Waktu (detik)'); ylabel('Amplitude'); xlim([0 5]);
    grid on;

end

set(gcf,'Color','w');
saveas(gcf,'Visualisasi Representative Channel.png');

%% SIGNAL TRIMMING
disp('Melakukan Signal Trimming...');

start_detik = 1;     
durasi_stimulus = 44; % detik

idx_start = round(start_detik*fs)+1;
idx_end = idx_start + round(durasi_stimulus*fs)-1;

if idx_end > size(data_bandpass,1)

    idx_end = size(data_bandpass,1);

end

data_trim = data_bandpass(idx_start:idx_end,:);
disp('Signal Trimming selesai.');

t_trim = (0:size(data_trim,1)-1)/fs;
% SIMPAN HASIL 
tabel_trim = array2table(...
    data_trim,...
    'VariableNames',channel_names);

writetable(tabel_trim,...
    'shk002_trim.xlsx');

disp('Data trimming berhasil disimpan.');

% visual PERBANDINGAN BANDPASS VS TRIMMING
t_before = (0:size(data_bandpass,1)-1)/fs;

figure('Name','Bandpass vs Trimming',...
    'Position',[120 80 1300 700]);

subplot(2,1,1)
spacing_before = max(std(data_bandpass-mean(data_bandpass,1)))*8;

plot(t_before,...
    (data_bandpass-mean(data_bandpass,1))+...
    (num_channels:-1:1)*spacing_before,...
    'b');

hold on

xline(start_detik,'r--','Start','LineWidth',2);
xline(start_detik+durasi_stimulus,...
    'r--','End','LineWidth',2);

yticks((1:num_channels)*spacing_before); yticklabels(flip(channel_names));
title(' '); xlabel('Waktu (detik)'); ylabel('Kanal');
grid on;

subplot(2,1,2)
spacing_after = max(std(data_trim-mean(data_trim,1)))*8;

plot(t_trim,...
    (data_trim-mean(data_trim,1))+...
    (num_channels:-1:1)*spacing_after,...
    'Color',[0 0.5 0]);

yticks((1:num_channels)*spacing_after); yticklabels(flip(channel_names));
title(' '); xlabel('Waktu (detik)'); ylabel('Kanal');
grid on; set(gcf,'Color','w');

saveas(gcf,'Visualisasi Bandpass vs Trimming.png');

%% MANUAL SPIKE REJECT
disp('Melakukan Manual Artifact Rejection...');

data_clean = data_trim;

baris_spike = [820:920,...
               1080:1200,...
               12788:13154,...
               13288:13304,...
               16400:16560];

% Jika tidak ada spike
if isempty(baris_spike)

    disp('Tidak ditemukan spike. Data tidak diubah.');

else

    % Pastikan indeks tidak melebihi jumlah sampel
    baris_spike = baris_spike(baris_spike <= size(data_clean,1));

    data_clean(baris_spike,:) = [];

    fprintf('Jumlah sampel yang dihapus : %d\n',length(baris_spike));

end

% SIMPAN HASIL
tabel_clean = array2table(...
    data_clean,...
    'VariableNames',channel_names);

writetable(tabel_clean,...
    'shk002_clean.xlsx');

disp('Data hasil Manual Artifact berhasil disimpan.');

% VISUALISASI SEBELUM VS SESUDAH
figure('Name','Manual Artifact Rejection',...
    'Position',[100 70 1300 700]);

t_before = (0:size(data_trim,1)-1)/fs;
t_after = (0:size(data_clean,1)-1)/fs;

subplot(2,1,1)

spacing_before = max(std(data_trim-mean(data_trim,1)))*8;
plot(t_before,...
    (data_trim-mean(data_trim,1))+...
    (num_channels:-1:1)*spacing_before,...
    'Color',[0.7 0 0]);

yticks((1:num_channels)*spacing_before); yticklabels(flip(channel_names));
title('Sebelum'); xlabel('Waktu (detik)'); ylabel('Kanal'); xlim([0 5]); grid on;

subplot(2,1,2)
spacing_after = max(std(data_clean-mean(data_clean,1)))*8;

plot(t_after,...
    (data_clean-mean(data_clean,1))+...
    (num_channels:-1:1)*spacing_after,...
    'Color',[0 0.5 0]);

yticks((1:num_channels)*spacing_after); yticklabels(flip(channel_names));
title('Sesudah Manual Artifact Rejection'); xlabel('Waktu (detik)'); ylabel('Kanal');
xlim([0 5]); grid on; set(gcf,'Color','w');

saveas(gcf,...
    'Visualisasi Sebelum vs Sesudah.png');

% VISUALISASI DATA CLEAN

figure('Name','Data Clean',...
    'Position',[100 80 1300 650]);

spacing = max(std(data_clean-mean(data_clean,1)))*8;
plot(t_after,...
    (data_clean-mean(data_clean,1))+...
    (num_channels:-1:1)*spacing,...
    'Color',[0 0.45 0]);

yticks((1:num_channels)*spacing); yticklabels(flip(channel_names));
xlabel('Waktu (detik)'); ylabel('Kanal');
title('Visualisasi Data Setelah Manual Artifact Rejection');
xlim([0 5]); grid on; set(gcf,'Color','w');

saveas(gcf,...
    'Visualisasi Manual Artifact.png');

%% EKSTRAKSI FITUR HIBRIDA (SUB-BAND POWER + FITUR STATISTIK)
disp('Memulai proses ekstraksi fitur...');

num_channels = size(data_clean,2);

% 4 Sub-Band + 9 Statistik = 13 fitur
features = zeros(num_channels,13);
for c = 1:num_channels

    signal = data_clean(:,c);

    % SUB-BAND POWER
    bp_low_alpha  = bandpower(signal,fs,[8 10]);
    bp_high_alpha = bandpower(signal,fs,[10 13]);
    bp_low_beta   = bandpower(signal,fs,[13 20]);
    bp_high_beta  = bandpower(signal,fs,[20 30]);

    % FITUR STATISTIK
    mean_value     = mean(signal);
    median_value   = median(signal);
    mode_value     = mode(signal);
    std_value      = std(signal);
    variance_value = var(signal);
    skew_value     = skewness(signal);
    kurt_value     = kurtosis(signal);

    % SHANNON ENTROPY
    jumlah_bin = 50;
    [counts,~] = histcounts(signal,jumlah_bin,...
        'Normalization','probability');

    counts = counts(counts>0);
    entropy_value = -sum(counts.*log2(counts));

    % ENERGY
    energy_value = sum(signal.^2);

    % GABUNGKAN FITUR
    features(c,:) = [...
        bp_low_alpha,...
        bp_high_alpha,...
        bp_low_beta,...
        bp_high_beta,...
        mean_value,...
        median_value,...
        mode_value,...
        std_value,...
        variance_value,...
        skew_value,...
        kurt_value,...
        entropy_value,...
        energy_value];

end
disp('Ekstraksi fitur selesai.');

% NAMA FITUR
col_names = {...
    'LowAlpha',...
    'HighAlpha',...
    'LowBeta',...
    'HighBeta',...
    'Mean',...
    'Median',...
    'Mode',...
    'Std',...
    'Variance',...
    'Skewness',...
    'Kurtosis',...
    'Entropy',...
    'Energy'};

% MEMBUAT TABEL FITUR
features_table = array2table(features,...
    'VariableNames',col_names);

% Tambahkan nama kanal
features_table.Channel = channel_names';

% Pindahkan ke kolom pertama
features_table = movevars(features_table,...
    'Channel','Before','LowAlpha');

% Tambahkan label
features_table.Label = repmat(label,num_channels,1);

% SIMPAN
writetable(features_table,...
    'shk002_features.xlsx');

disp('Fitur berhasil disimpan.');

% VISUALISASI SUB-BAND POWER
figure('Position',[100 100 1300 600]);

bar(features(:,1:4),'grouped');
set(gca,...
    'XTick',1:num_channels,...
    'XTickLabel',channel_names,...
    'XTickLabelRotation',45);

xlabel('Kanal'); ylabel('Band Power'); title('Distribusi Sub-Band Power');
legend({'Low Alpha',...
        'High Alpha',...
        'Low Beta',...
        'High Beta'},...
        'Location','northwest');
grid on;
saveas(gcf,...
    'Visualisasi - Analisis Sub-Band Power.png');

% VISUALISASI FITUR STATISTIK
figure('Position',[100 100 1500 650]);

bar(features(:,5:end),'grouped');
set(gca,...
    'XTick',1:num_channels,...
    'XTickLabel',channel_names,...
    'XTickLabelRotation',45);

xlabel('Kanal'); ylabel('Nilai Fitur'); title('Distribusi Fitur Statistik');
legend({'Mean',...
        'Median',...
        'Mode',...
        'Std',...
        'Variance',...
        'Skewness',...
        'Kurtosis',...
        'Entropy',...
        'Energy'},...
        'Location','eastoutside');
grid on;
saveas(gcf,...
'Visualisasi - Analisis Statistik.png');