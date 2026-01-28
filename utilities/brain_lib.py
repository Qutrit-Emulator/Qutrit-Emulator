
import struct

class InfiniteBrain:
    def __init__(self, weights_path='mastered.weights'):
        self.weights = []
        try:
            with open(weights_path, 'rb') as f:
                # Read 4096 * 8 bytes (64-bit integers)
                data = f.read(4096 * 8)
                self.weights = list(struct.unpack(f'<{len(data)//8}q', data))
            print(f"[Brain] Loaded {len(self.weights)} base synaptic weights.")
        except FileNotFoundError:
            print("[Error] mastered.weights not found. Run generator first.")
            self.weights = [0] * 4096

    def get_synapse(self, index):
        """
        Replicates the ASM 'Infinite Brain' hashing logic exactly.
        custom_oracles.asm:
            mov rax, rbx
            and rax, 4095
            mov rcx, [r14 + rax*8]  ; Base Weight
            
            mov rdx, rbx
            imul rdx, 0x9E3779B97F4A7C15
            xor rcx, rdx
            ...
        """
        # 1. Base Weight
        base = self.weights[index % 4096]
        
        # 2. Hashing (64-bit arithmetic)
        MASK64 = 0xFFFFFFFFFFFFFFFF
        
        # rdx = index * PRIME1
        rdx = (index * 0x9E3779B97F4A7C15) & MASK64
        
        # rcx = base ^ rdx
        h = base ^ rdx
        
        # rdx = h >> 30; rcx ^= rdx
        h = h ^ (h >> 30)
        
        # rcx *= PRIME2
        h = (h * 0xBF58476D1CE4E5B9) & MASK64
        
        return h

    def stream(self, start_index, length):
        for i in range(length):
            yield self.get_synapse(start_index + i)

    def encrypt(self, plain_text, start_index=0):
        """
        Encrypts text using the Brain as a One-Time Pad (XOR).
        """
        cipher_bytes = []
        text_bytes = plain_text.encode('utf-8')
        
        for i, byte in enumerate(text_bytes):
            # Get 64-bit brain weight
            brain_w = self.get_synapse(start_index + i)
            # Use lowest 8 bits for XOR
            key_byte = brain_w & 0xFF
            cipher_bytes.append(byte ^ key_byte)
            
        return bytes(cipher_bytes)

    def decrypt(self, cipher_bytes, start_index=0):
        # XOR is symmetric
        plain_bytes = []
        for i, byte in enumerate(cipher_bytes):
            brain_w = self.get_synapse(start_index + i)
            key_byte = brain_w & 0xFF
            plain_bytes.append(byte ^ key_byte)
            
        return bytes(plain_bytes).decode('utf-8', errors='ignore')

if __name__ == "__main__":
    # Test
    brain = InfiniteBrain()
    idx = 123456789
    val = brain.get_synapse(idx)
    print(f"Synapse[{idx}] = {hex(val)}")
    
    msg = "The Future is Written."
    enc = brain.encrypt(msg, idx)
    print(f"Encrypted: {enc.hex()}")
    dec = brain.decrypt(enc, idx)
    print(f"Decrypted: {dec}")
