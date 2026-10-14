import os
import numpy as np

def generate_synthetic_dataset(num_sequences=1000, seq_len=50, anomaly_ratio=0.2):
    np.random.seed(42)
    data = []
    labels = [] # 0.0 for normal, 1.0 for anomaly

    for _ in range(num_sequences):
        is_anomaly = np.random.rand() < anomaly_ratio
        
        # Base normal operation values with slight noise
        t = np.linspace(0, 10, seq_len)
        pressure = 220.0 + 2.0 * np.sin(t) + np.random.normal(0, 0.5, seq_len)
        rpm = 1480.0 + 10.0 * np.cos(t) + np.random.normal(0, 2.0, seq_len)
        temp = 41.0 + 1.0 * (t / 10.0) + np.random.normal(0, 0.3, seq_len)
        flow = 75.0 + 1.5 * np.sin(t) + np.random.normal(0, 0.4, seq_len)
        
        if is_anomaly:
            anomaly_type = np.random.choice(['spike', 'drift', 'frozen'])
            if anomaly_type == 'spike':
                idx = np.random.randint(10, seq_len - 10)
                pressure[idx:idx+3] += np.random.uniform(25, 40)
            elif anomaly_type == 'drift':
                drift_start = np.random.randint(5, 20)
                temp[drift_start:] += np.linspace(0, 15, seq_len - drift_start)
            elif anomaly_type == 'frozen':
                idx = np.random.randint(10, seq_len - 15)
                rpm[idx:idx+10] = rpm[idx]
            
            labels.append(1.0)
        else:
            labels.append(0.0)
            
        # Shape: (seq_len, 4 features)
        seq = np.column_stack([pressure, rpm, temp, flow])
        data.append(seq)
        
    return np.array(data, dtype=np.float32), np.array(labels, dtype=np.float32)

if __name__ == '__main__':
    print("Generating synthetic telemetry datasets...")
    X_train, y_train = generate_synthetic_dataset(num_sequences=800)
    X_val, y_val = generate_synthetic_dataset(num_sequences=200)
    
    np.save('ml/data/X_train.npy', X_train)
    np.save('ml/data/y_train.npy', y_train)
    np.save('ml/data/X_val.npy', X_val)
    np.save('ml/data/y_val.npy', y_val)
    print("Dataset saved successfully in ml/data/!")
