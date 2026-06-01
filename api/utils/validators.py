import re
from typing import List, Tuple
from ipaddress import ip_address, IPv4Address, IPv6Address

class Validators:
    """Input validation utilities."""
    
    @staticmethod
    def validate_ip_address(ip: str) -> bool:
        """Validate IPv4 or IPv6 address."""
        try:
            ip_address(ip)
            return True
        except ValueError:
            return False
    
    @staticmethod
    def validate_frequency_deltas(deltas: List[float]) -> Tuple[bool, str]:
        """Validate frequency amplitude delta array."""
        if not deltas:
            return False, "Empty frequency array"
        
        if len(deltas) < 10:
            return False, f"Insufficient samples: {len(deltas)} (minimum 10)"
        
        if len(deltas) > 1000:
            return False, f"Too many samples: {len(deltas)} (maximum 1000)"
        
        for i, val in enumerate(deltas):
            if val < 0 or val > 10:
                return False, f"Invalid value at index {i}: {val} (must be 0-10)"
        
        return True, "Valid"
    
    @staticmethod
    def validate_channel_identity(channel: str) -> Tuple[bool, str]:
        """Validate channel identity format."""
        if not channel:
            return False, "Empty channel identity"
        
        if len(channel) > 100:
            return False, f"Channel identity too long: {len(channel)} (max 100)"
        
        # Allow alphanumeric, underscores, hyphens, and dots
        if not re.match(r'^[a-zA-Z0-9_\-\.]+$', channel):
            return False, f"Invalid characters in channel identity: {channel}"
        
        return True, "Valid"
    
    @staticmethod
    def sanitize_input(text: str, max_length: int = 1000) -> str:
        """Sanitize user input to prevent injection."""
        # Remove control characters
        sanitized = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', text)
        # Truncate to max length
        if len(sanitized) > max_length:
            sanitized = sanitized[:max_length]
        return sanitized
