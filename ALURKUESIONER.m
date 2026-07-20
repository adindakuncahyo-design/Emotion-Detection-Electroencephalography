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

Dataset = table();

for i = 1:length(files)

    fprintf('Membaca %s\n', files{i});
    T = readtable(files{i});
    [~, namaFile, ~] = fileparts(files{i}); % Ambil nama subjek dari nama file

    subjectID = regexp(upper(namaFile), 'SHK\d+', 'match');
    subjectID = subjectID{1};

    T.Subject = repmat(string(subjectID), height(T), 1); % Tambahkan kolom subjek

    T = movevars(T, 'Subject', 'Before', 1); % Pindahkan ke kolom pertama

    Dataset = [Dataset; T];

end

disp('Penggabungan data selesai!');
fprintf('\n');
fprintf('Jumlah Sampel : %d\n',height(Dataset));
fprintf('Jumlah Kolom  : %d\n',width(Dataset));
fprintf('\n');
disp(summary(Dataset));

% Simpan
writetable(Dataset,'Dataset_Kuesioner.xlsx');
disp('Dataset berhasil disimpan.');

%% VALIDASI DATASET

disp('VALIDASI DATASET');

Dataset = readtable('Dataset_Kuesioner.xlsx');

fprintf('Jumlah Sampel : %d\n',height(Dataset));
fprintf('Jumlah Kolom  : %d\n',width(Dataset));
disp('Nama Variabel');
disp(Dataset.Properties.VariableNames');
fprintf('Jumlah Missing Value : %d\n',...
sum(ismissing(Dataset),'all'));
fprintf('Jumlah NaN : %d\n',...
sum(isnan(table2array(Dataset(:,3:15))),'all'));

summary(Dataset)

%% PEMISAHAN FITUR DAN LABEL
X = table2array(Dataset(:,3:15));

Y = Dataset.Label;

%% TRAIN TEST SPLIT
rng(42)

cv = cvpartition(Y,'HoldOut',0.2);

idxTrain = training(cv);
idxTest  = test(cv);


X_train = X(idxTrain,:); X_test  = X(idxTest,:);

y_train = Y(idxTrain); y_test  = Y(idxTest);

fprintf('\n');
fprintf('Training : %d sampel\n',length(y_train));
fprintf('Testing  : %d sampel\n',length(y_test));

% DISTRIBUSI KELAS TRAIN DAN TEST

disp('DISTRIBUSI DATA TRAINING DAN TESTING');

% Training
train_neg = sum(y_train==0);
train_pos = sum(y_train==1);

% Testing
test_neg = sum(y_test==0);
test_pos = sum(y_test==1);

% Persentase
train_neg_pct = train_neg/length(y_train)*100;
train_pos_pct = train_pos/length(y_train)*100;

test_neg_pct = test_neg/length(y_test)*100;
test_pos_pct = test_pos/length(y_test)*100;

fprintf('\nDATA TRAINING\n');
fprintf('Total              : %d\n',length(y_train));
fprintf('Negatif (0)        : %d (%.2f%%)\n',train_neg,train_neg_pct);
fprintf('Non-Negatif (1)    : %d (%.2f%%)\n',train_pos,train_pos_pct);

fprintf('\nDATA TESTING\n');
fprintf('Total              : %d\n',length(y_test));
fprintf('Negatif (0)        : %d (%.2f%%)\n',test_neg,test_neg_pct);
fprintf('Non-Negatif (1)    : %d (%.2f%%)\n',test_pos,test_pos_pct);

%% SVM
modelSVM = fitcsvm(...
    X_train,...
    y_train,...
    'KernelFunction','rbf',...
    'Standardize',true);

predSVM = predict(modelSVM,X_test); 

cmSVM = confusionmat(y_test,predSVM);
hasilSVM = hitung_metrik(y_test,predSVM);
disp('HASIL SVM');
disp(hasilSVM)

figure;
confusionchart(y_test,predSVM);
title('Confusion Matrix SVM');

saveas(gcf,'ConfusionMatrix_SVM.png');

%% Random Forest
tree = templateTree('MinLeafSize',10);

modelRF = fitcensemble(...
    X_train,...
    y_train,...
    'Method','Bag',...
    'NumLearningCycles',200,...
    'Learners',tree);

predRF = predict(modelRF,X_test);

cmRF = confusionmat(y_test,predRF);
hasilRF = hitung_metrik(y_test,predRF);
disp('HASIL RANDOM FOREST');
disp(hasilRF)

figure;
confusionchart(y_test,predRF);
title('Confusion Matrix Random Forest');

saveas(gcf,'ConfusionMatrix_RF.png');

%% Evaluasi
function hasil = hitung_metrik(y_true,y_pred)

cm = confusionmat(y_true,y_pred);

TN = cm(1,1);
FP = cm(1,2);
FN = cm(2,1);
TP = cm(2,2);

hasil.Accuracy = (TP+TN)/sum(cm(:));

hasil.Precision = TP/(TP+FP);

hasil.Recall = TP/(TP+FN);

hasil.Specificity = TN/(TN+FP);

hasil.F1 = 2*((hasil.Precision*hasil.Recall)/...
    (hasil.Precision+hasil.Recall));

hasil.CM = cm;

end

% AKURASI TRAINING

% SVM
predTrainSVM = predict(modelSVM,X_train);

accTrainSVM = mean(predTrainSVM==y_train);

% Random Forest
predTrainRF = predict(modelRF,X_train);

accTrainRF = mean(predTrainRF==y_train);

fprintf('AKURASI TRAINING\n');
fprintf('SVM            : %.2f %%\n',accTrainSVM*100);
fprintf('Random Forest  : %.2f %%\n',accTrainRF*100);

% AKURASI TESTING
accTestSVM = mean(predSVM==y_test);

accTestRF = mean(predRF==y_test);

fprintf('AKURASI TESTING\n');
fprintf('SVM            : %.2f %%\n',accTestSVM*100);
fprintf('Random Forest  : %.2f %%\n',accTestRF*100);

% GRAFIK TRAINING VS TESTING
figure('Position',[200 150 700 450]);

akurasi = [...
    accTrainSVM accTestSVM;
    accTrainRF accTestRF];

bar(akurasi)

set(gca,...
'XTickLabel',{'SVM','Random Forest'});

legend({'Training','Testing'},...
'Location','northwest');

ylabel('Accuracy');
title('Perbandingan Akurasi Training dan Testing');
grid on
saveas(gcf,...
'Akurasi_Training_vs_Testing.png');

% grafik Accuracy
figure;
akurasi = [hasilSVM.Accuracy hasilRF.Accuracy];
bar(akurasi)

set(gca,'XTickLabel',{'SVM','Random Forest'})
ylabel('Accuracy')
title('Perbandingan Accuracy')
grid on

saveas(gcf,'Perbandingan_Accuracy.png')

% grafik precision
figure;
precision = [hasilSVM.Precision hasilRF.Precision];
bar(precision)

set(gca,'XTickLabel',{'SVM','Random Forest'})
ylabel('Precision')
title('Perbandingan Precision')
grid on

saveas(gcf,'Perbandingan_Precision.png')

% grafik recall
figure;
recall = [hasilSVM.Recall hasilRF.Recall];
bar(recall)

set(gca,'XTickLabel',{'SVM','Random Forest'})
ylabel('Recall')
title('Perbandingan Recall')
grid on

saveas(gcf,'Perbandingan_Recall.png')

% grafik F1
figure;
f1 = [hasilSVM.F1 hasilRF.F1];
bar(f1)

set(gca,'XTickLabel',{'SVM','Random Forest'})
ylabel('F1 Score')
title('Perbandingan F1 Score')
grid on

saveas(gcf,'Perbandingan_F1Score.png')

%Hasil
Model = {'SVM';'Random Forest'};

TrainingAccuracy = [...
accTrainSVM;
accTrainRF];

TestingAccuracy = [...
accTestSVM;
accTestRF];

Accuracy = [...
hasilSVM.Accuracy;
hasilRF.Accuracy];

Precision = [...
hasilSVM.Precision;
hasilRF.Precision];

Recall = [...
hasilSVM.Recall;
hasilRF.Recall];

Specificity = [...
hasilSVM.Specificity;
hasilRF.Specificity];

F1Score = [...
hasilSVM.F1;
hasilRF.F1];

hasil_tabel = table(...
Model,...
TrainingAccuracy,...
TestingAccuracy,...
Accuracy,...
Precision,...
Recall,...
Specificity,...
F1Score);

writetable(hasil_tabel,...
'Hasil Performa Model.xlsx');

% SIMPAN DISTRIBUSI TRAIN DAN TEST
Distribusi = table(...
["Training";"Testing"],...
[train_neg;test_neg],...
[train_pos;test_pos],...
[train_neg_pct;test_neg_pct],...
[train_pos_pct;test_pos_pct],...
'VariableNames',...
{'Dataset','Negatif','NonNegatif',...
'PersenNegatif','PersenNonNegatif'});

writetable(Distribusi,...
'Distribusi_Train_Test.xlsx');

disp('Rekap performa model berhasil disimpan.')