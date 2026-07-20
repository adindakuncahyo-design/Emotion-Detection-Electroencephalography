clear; clc; close all;
%% MERGE DATASET
disp('Menggabungkan seluruh dataset...');

files = {...
'shk001_features.xlsx',...
'shk002_features.xlsx',...
'shk003_features.xlsx',...
'shk004_features.xlsx',...
'shk005_features.xlsx',...
'shk006_features.xlsx',...
'shk007_features.xlsx',...
'shk008_features.xlsx',...
'shk009_features.xlsx',...
'shk010_features.xlsx'};

Dataset = table();

for i = 1:length(files)

    fprintf('\nMembaca %s\n',files{i});

    T = readtable(files{i});

    % Tambahkan Subject

    [~,nama,~] = fileparts(files{i});

    subjectID = regexp(upper(nama),...
        'SHK\d+',...
        'match');

    subjectID = subjectID{1};

    T.Subject = repmat(string(subjectID),height(T),1);

    T = movevars(T,...
        'Subject',...
        'Before',...
        1);
    Dataset = [Dataset;T];

end

disp(' ')
disp('SEMUA DATA BERHASIL DIGABUNGKAN')

% Simpan
writetable(Dataset,...
'Dataset_Frontal.xlsx');

disp('Dataset_Frontal.xlsx berhasil dibuat')

% VALIDASI
fprintf('Jumlah Sampel : %d\n',height(Dataset));
fprintf('Jumlah Kolom : %d\n',width(Dataset));
disp('Nama Variabel')
disp(Dataset.Properties.VariableNames')

fprintf('Jumlah Subject : %d\n',...
length(unique(Dataset.Subject)));

missingValue = sum(ismissing(Dataset),'all');
fprintf('Missing Value : %d\n',missingValue);

fitur = Dataset(:,3:end);
jumlahNaN = sum(isnan(table2array(fitur)),'all');

fprintf('NaN : %d\n',jumlahNaN);

disp(' ')
disp(summary(Dataset))

%% MEMBENTUK 19 KOMBINASI KANAL
Dataset = readtable('Dataset_Frontal.xlsx');
Ringkasan = table();

disp('DATASET BERHASIL DIBACA')
fprintf('Jumlah Sampel : %d\n',height(Dataset));
fprintf('Jumlah Kolom  : %d\n',width(Dataset));

% DAFTAR KANAL
Left = {'Fp1_A1','F3_A1','F7_A1'};
Right = {'Fp2_A2','F4_A2','F8_A2'};
kombinasi = {};
k = 1;

% 1 VS 1
for i = 1:length(Left)
    for j = 1:length(Right)
        kombinasi{k}.Left = Left(i);
        kombinasi{k}.Right = Right(j);
        k = k + 1;
    end
end

% 2 VS 2
leftPair = nchoosek(1:3,2);
rightPair = nchoosek(1:3,2);

for i = 1:size(leftPair,1)
    for j = 1:size(rightPair,1)
        kombinasi{k}.Left = Left(leftPair(i,:));
        kombinasi{k}.Right = Right(rightPair(j,:));
        k = k + 1;
    end
end

% 3 VS 3
kombinasi{k}.Left = Left;
kombinasi{k}.Right = Right;
fprintf('\nJumlah kombinasi : %d\n',length(kombinasi));

%% LOOP KOMBINASI
HasilSemuaKombinasi = table();
%Folder Visualisasi
folderCM = 'Visual CM';
if ~exist(folderCM,'dir')
    mkdir(folderCM);
end

for k = 1:length(kombinasi)

    fprintf('KOMBINASI %d\n',k);
    leftChannel = kombinasi{k}.Left;
    rightChannel = kombinasi{k}.Right;

    fprintf('Negatif     : ');
    disp(strjoin(leftChannel,', '));

    fprintf('Non-Negatif : ');
    disp(strjoin(rightChannel,', '));

    %filter dataset
    idxLeft = ismember(string(Dataset.Channel),leftChannel);
    idxRight = ismember(string(Dataset.Channel),rightChannel);
    DatasetBaru = Dataset(idxLeft | idxRight,:);

    fprintf("Jumlah sampel kombinasi = %d\n",height(DatasetBaru));
    disp(unique(string(DatasetBaru.Channel)))    

    %LABEL
    DatasetBaru.Label = zeros(height(DatasetBaru),1);  % Default = Negatif (0)
    
    idx = ismember(string(DatasetBaru.Channel), leftChannel);
    DatasetBaru.Label(idx) = 1; % Non-Negatif (1)    
    disp('Distribusi Label')
    tabulate(DatasetBaru.Label)

    % PEMISAHAN FITUR DAN LABEL
    fitur = setdiff(...
    DatasetBaru.Properties.VariableNames,...
    {'Subject','Channel','Label'},...
    'stable');

    X = DatasetBaru{:,fitur};
    Y = DatasetBaru.Label;
    
    disp("Ukuran DatasetBaru:");
    disp(size(DatasetBaru));
    
    disp("Jumlah sampel tiap kelas:");
    tabulate(Y)
    % TRAIN TEST SPLIT    
    rng(42)
    cv = cvpartition(Y,'HoldOut',0.2);
    
    idxTrain = training(cv); idxTest  = test(cv);
    
    X_train = X(idxTrain,:); X_test  = X(idxTest,:);
    
    y_train = Y(idxTrain); y_test  = Y(idxTest);

    jumlahSampel = height(DatasetBaru);

    jumlahTrain = length(y_train);
    jumlahTest  = length(y_test);
    
    trainNeg = sum(y_train==0);
    trainPos = sum(y_train==1);
    
    testNeg = sum(y_test==0);
    testPos = sum(y_test==1);
    
    fprintf('\nTraining : %d\n',length(y_train));
    fprintf('Testing  : %d\n',length(y_test));
    
    disp('Distribusi Training')
    tabulate(y_train)
    disp('Distribusi Testing')
    tabulate(y_test)

    %% SVM    
    modelSVM = fitcsvm(...
        X_train,...
        y_train,...
        'KernelFunction','rbf',...
        'Standardize',true);
    
    predSVM = predict(modelSVM,X_test); % Prediksi
    
    hasilSVM = hitung_metrik(y_test,predSVM); %Evaluasi
    CM_SVM = mat2str(hasilSVM.CM);
    
    %Akurasi Training
    predTrainSVM = predict(modelSVM,X_train);
    accTrainSVM = mean(predTrainSVM==y_train);
    
    %Akurasi Testing
    accTestSVM = mean(predSVM==y_test);
    
    fprintf('\nTraining Accuracy : %.2f %%\n',...
        accTrainSVM*100);
    fprintf('Testing Accuracy : %.2f %%\n',...
        accTestSVM*100);
    
    fig = figure('Visible','off');
    
    confusionchart(y_test,predSVM);
    
    title(sprintf('SVM - Kombinasi %d',k));
    
    saveas(fig,...
        fullfile(folderCM,...
        sprintf('Kombinasi_%02d_SVM.png',k)));
    
    close(fig);

    % RANDOM FOREST        
    tree = templateTree(...
        'MinLeafSize',10);
    
    modelRF = fitcensemble(...
        X_train,...
        y_train,...
        'Method','Bag',...
        'NumLearningCycles',250,...
        'Learners',tree);

    predRF = predict(modelRF,X_test); % Prediksi
       
    hasilRF = hitung_metrik(y_test,predRF); % Evaluasi
    CM_RF = mat2str(hasilRF.CM);
    
    % Akurasi Training
    predTrainRF = predict(modelRF,X_train);   
    accTrainRF = mean(predTrainRF==y_train);
    
    % Akurasi Testing
    accTestRF = mean(predRF==y_test);
    
    fprintf('\nTraining Accuracy : %.2f %%\n',...
        accTrainRF*100);
    fprintf('Testing Accuracy : %.2f %%\n',...
        accTestRF*100);

    fig = figure('Visible','off');
    
    confusionchart(y_test,predRF);
    
    title(sprintf('Random Forest - Kombinasi %d',k));
    
    saveas(fig,...
        fullfile(folderCM,...
        sprintf('Kombinasi_%02d_RF.png',k)));
    
    close(fig);

    % Simpan hasil kombinasi
    hasilBaru = table(...
        k,...
        string(strjoin(kombinasi{k}.Left,", ")),...
        string(strjoin(kombinasi{k}.Right,", ")),...
        jumlahSampel,...
        jumlahTrain,...
        jumlahTest,...
        trainNeg,...
        trainPos,...
        testNeg,...
        testPos,...
        accTrainSVM,...
        accTestSVM,...
        hasilSVM.Accuracy,...
        hasilSVM.Precision,...
        hasilSVM.Recall,...
        hasilSVM.Specificity,...
        hasilSVM.F1,...
        string(CM_SVM),...
        accTrainRF,...
        accTestRF,...
        hasilRF.Accuracy,...
        hasilRF.Precision,...
        hasilRF.Recall,...
        hasilRF.Specificity,...
        hasilRF.F1,...
        string(CM_RF),...
    'VariableNames',{...
    'Kombinasi',...
    'KanalNegatif',...
    'KanalNonNegatif',...
    'JumlahSampel',...
    'JumlahTrain',...
    'JumlahTest',...
    'TrainNegatif',...
    'TrainNonNegatif',...
    'TestNegatif',...
    'TestNonNegatif',...
    'SVM_Train',...
    'SVM_Test',...
    'SVM_Accuracy',...
    'SVM_Precision',...
    'SVM_Recall',...
    'SVM_Specificity',...
    'SVM_F1',...
    'SVM_CM',...
    'RF_Train',...
    'RF_Test',...
    'RF_Accuracy',...
    'RF_Precision',...
    'RF_Recall',...
    'RF_Specificity',...
    'RF_F1',...
    'RF_CM'});
        
    Ringkasan = [Ringkasan; hasilBaru];

end

disp(Ringkasan)

writetable(Ringkasan,...
'Ringkasan_19_Kombinasi.xlsx');

function hasil = hitung_metrik(y_true,y_pred)
cm = confusionmat(y_true,y_pred);

TN = cm(1,1);
FP = cm(1,2);
FN = cm(2,1);
TP = cm(2,2);

hasil.Accuracy = (TP+TN)/sum(cm(:));

hasil.Precision = TP/(TP+FP);
if isnan(hasil.Precision)
    hasil.Precision = 0;
end

hasil.Recall = TP/(TP+FN);
if isnan(hasil.Recall)
    hasil.Recall = 0;
end

hasil.Specificity = TN/(TN+FP);
if isnan(hasil.Specificity)
    hasil.Specificity = 0;
end

hasil.F1 = 2*(hasil.Precision*hasil.Recall) / ...
          (hasil.Precision+hasil.Recall);
if isnan(hasil.F1)
    hasil.F1 = 0;
end
hasil.CM = cm;

end

%% RATA-RATA AKURASI BERDASARKAN JUMLAH KANAL (%)

% 1 vs 1 (kombinasi 1-9)
SVM11 = mean(Ringkasan.SVM_Accuracy(1:9))*100;
RF11  = mean(Ringkasan.RF_Accuracy(1:9))*100;

% 2 vs 2 (kombinasi 10-18)
SVM22 = mean(Ringkasan.SVM_Accuracy(10:18))*100;
RF22  = mean(Ringkasan.RF_Accuracy(10:18))*100;

% 3 vs 3 (kombinasi 19)
SVM33 = Ringkasan.SVM_Accuracy(19)*100;
RF33  = Ringkasan.RF_Accuracy(19)*100;

RataRataKanal = table(...
    ["1 vs 1";"2 vs 2";"3 vs 3"],...
    [SVM11;SVM22;SVM33],...
    [RF11;RF22;RF33],...
    'VariableNames',...
    {'KombinasiKanal','SVM_AkurasiPersen','RF_AkurasiPersen'});

disp('==========================================');
disp('RATA-RATA AKURASI BERDASARKAN JUMLAH KANAL (%)');
disp(RataRataKanal);

fprintf('\n===== RATA-RATA AKURASI (%%) =====\n');
fprintf('1 vs 1 : SVM = %.2f%% | RF = %.2f%%\n',SVM11,RF11);
fprintf('2 vs 2 : SVM = %.2f%% | RF = %.2f%%\n',SVM22,RF22);
fprintf('3 vs 3 : SVM = %.2f%% | RF = %.2f%%\n',SVM33,RF33);

writetable(RataRataKanal,...
    'RataRata_Akurasi_KombinasiKanal.xlsx');