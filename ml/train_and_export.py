import os
import json
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader

class Tiny1DCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv1d(4, 8, kernel_size=3, padding=1)
        self.pool1 = nn.MaxPool1d(2)
        self.conv2 = nn.Conv1d(8, 16, kernel_size=3, padding=1)
        self.pool2 = nn.MaxPool1d(2)
        self.fc1 = nn.Linear(16 * 12, 16)
        self.fc2 = nn.Linear(16, 1)
        
    def forward(self, x):
        # x shape: (batch, 50, 4) -> transpose to (batch, 4, 50)
        x = x.permute(0, 2, 1)
        x = self.pool1(torch.relu(self.conv1(x)))
        x = self.pool2(torch.relu(self.conv2(x)))
        x = x.view(x.size(0), -1)
        x = torch.relu(self.fc1(x))
        x = torch.sigmoid(self.fc2(x))
        return x

def main():
    print("Loading synthetic datasets...")
    X_train = np.load('ml/data/X_train.npy')
    y_train = np.load('ml/data/y_train.npy')
    X_val = np.load('ml/data/X_val.npy')
    y_val = np.load('ml/data/y_val.npy')
    
    # Compute global normalization stats from training data
    feature_means = X_train.mean(axis=(0, 1)).tolist()
    feature_stds = X_train.std(axis=(0, 1)).tolist()
    
    # Normalize datasets
    X_train_norm = (X_train - feature_means) / (np.array(feature_stds) + 1e-8)
    X_val_norm = (X_val - feature_means) / (np.array(feature_stds) + 1e-8)
    
    # Explicitly cast to float32 tensors to match model weights
    train_dataset = TensorDataset(
        torch.tensor(X_train_norm, dtype=torch.float32), 
        torch.tensor(y_train, dtype=torch.float32).unsqueeze(1)
    )
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
    
    model = Tiny1DCNN()
    criterion = nn.BCELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    
    print("Training Tiny 1D-CNN model...")
    model.train()
    for epoch in range(10):
        total_loss = 0
        for batch_x, batch_y in train_loader:
            optimizer.zero_grad()
            outputs = model(batch_x)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        print(f"Epoch {epoch+1}/10 - Loss: {total_loss/len(train_loader):.4f}")
        
    # Validation evaluation
    model.eval()
    with torch.no_grad():
        val_x = torch.tensor(X_val_norm, dtype=torch.float32)
        val_y = torch.tensor(y_val, dtype=torch.float32).unsqueeze(1)
        preds = model(val_x)
        pred_labels = (preds >= 0.5).float()
        accuracy = (pred_labels == val_y).float().mean().item()
        print(f"Validation Accuracy: {accuracy * 100:.2f}%")
        
    # Export weights & stats to JSON
    os.makedirs('assets/models', exist_ok=True)
    state = model.state_dict()
    
    export_data = {
        "model_name": "GridSentinel-CNN",
        "input_steps": 50,
        "feature_names": ["pressure_kpa", "motor_rpm", "temperature_c", "flow_lpm"],
        "normalization": {
            "mean": feature_means,
            "std": feature_stds
        },
        "weights": {
            "conv1_weight": state["conv1.weight"].tolist(),
            "conv1_bias": state["conv1.bias"].tolist(),
            "conv2_weight": state["conv2.weight"].tolist(),
            "conv2_bias": state["conv2.bias"].tolist(),
            "fc1_weight": state["fc1.weight"].tolist(),
            "fc1_bias": state["fc1.bias"].tolist(),
            "fc2_weight": state["fc2.weight"].tolist(),
            "fc2_bias": state["fc2.bias"].tolist()
        }
    }
    
    output_path = 'assets/models/gridsentinel_weights.json'
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    print(f"Model successfully trained and exported to {output_path}!")

if __name__ == '__main__':
    main()
