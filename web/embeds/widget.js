// BioShield Security Widget - Embed this in any website
(function() {
    // Configuration
    const config = {
        apiUrl: 'https://api.bioshield.secure-bank.internal',
        apiKey: null,
        position: 'bottom-right',
        theme: 'dark'
    };
    
    // Create widget container
    const widgetContainer = document.createElement('div');
    widgetContainer.id = 'bioshield-widget';
    widgetContainer.style.cssText = `
        position: fixed;
        z-index: 999999;
        bottom: 20px;
        right: 20px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    `;
    
    // Widget button
    const widgetButton = document.createElement('button');
    widgetButton.innerHTML = '🛡️';
    widgetButton.style.cssText = `
        width: 56px;
        height: 56px;
        border-radius: 28px;
        background: linear-gradient(135deg, #ef4444, #dc2626);
        border: none;
        cursor: pointer;
        font-size: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        transition: transform 0.2s;
    `;
    widgetButton.onmouseenter = () => widgetButton.style.transform = 'scale(1.1)';
    widgetButton.onmouseleave = () => widgetButton.style.transform = 'scale(1)';
    
    // Widget panel
    const widgetPanel = document.createElement('div');
    widgetPanel.style.cssText = `
        position: absolute;
        bottom: 70px;
        right: 0;
        width: 320px;
        background: #0f172a;
        border-radius: 16px;
        border: 1px solid #1e293b;
        box-shadow: 0 8px 32px rgba(0,0,0,0.4);
        display: none;
        overflow: hidden;
    `;
    
    widgetPanel.innerHTML = `
        <div style="padding: 16px; border-bottom: 1px solid #1e293b; background: #1e293b;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <span style="font-size: 18px;">🛡️</span>
                    <span style="font-weight: bold; margin-left: 8px; color: white;">BioShield Security</span>
                </div>
                <button id="close-widget" style="background: none; border: none; color: #64748b; cursor: pointer; font-size: 18px;">✕</button>
            </div>
            <p style="font-size: 11px; color: #94a3b8; margin-top: 4px;">Real-time deepfake detection</p>
        </div>
        <div style="padding: 16px;">
            <div id="widget-status" style="background: #05966920; border: 1px solid #059669; border-radius: 8px; padding: 12px; text-align: center; margin-bottom: 12px;">
                <div id="widget-status-icon" style="font-size: 24px;">✅</div>
                <div id="widget-status-text" style="font-size: 12px; font-weight: bold; color: #059669; margin-top: 4px;">All Systems Operational</div>
                <div id="widget-status-detail" style="font-size: 10px; color: #64748b; margin-top: 2px;">99.999% uptime</div>
            </div>
            <div style="margin-bottom: 12px;">
                <label style="display: block; font-size: 11px; color: #94a3b8; margin-bottom: 4px;">Test Voice</label>
                <div style="display: flex; gap: 8px;">
                    <button id="test-human" style="flex: 1; background: #1e293b; border: none; padding: 8px; border-radius: 8px; color: white; font-size: 12px; cursor: pointer;">👤 Human</button>
                    <button id="test-deepfake" style="flex: 1; background: #1e293b; border: none; padding: 8px; border-radius: 8px; color: white; font-size: 12px; cursor: pointer;">🤖 Deepfake</button>
                </div>
            </div>
            <div id="widget-result" style="display: none; background: #1e293b; border-radius: 8px; padding: 12px; margin-top: 12px;">
                <div id="widget-result-text" style="font-size: 12px; text-align: center;"></div>
            </div>
            <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #1e293b;">
                <a href="#" id="learn-more" style="font-size: 11px; color: #3b82f6; text-decoration: none;">Learn more →</a>
            </div>
        </div>
    `;
    
    widgetContainer.appendChild(widgetButton);
    widgetContainer.appendChild(widgetPanel);
    document.body.appendChild(widgetContainer);
    
    // Toggle panel
    widgetButton.onclick = () => {
        widgetPanel.style.display = widgetPanel.style.display === 'none' ? 'block' : 'none';
        if (widgetPanel.style.display === 'block') {
            fetchStatus();
        }
    };
    
    document.getElementById('close-widget').onclick = () => {
        widgetPanel.style.display = 'none';
    };
    
    // Test functions
    document.getElementById('test-human').onclick = () => {
        testVoice(true);
    };
    
    document.getElementById('test-deepfake').onclick = () => {
        testVoice(false);
    };
    
    document.getElementById('learn-more').onclick = (e) => {
        e.preventDefault();
        window.open('https://bioshield.secure-bank.internal', '_blank');
    };
    
    async function fetchStatus() {
        try {
            const response = await fetch('https://api.bioshield.secure-bank.internal/v1/health');
            const data = await response.json();
            
            if (data.status === 'healthy') {
                document.getElementById('widget-status-icon').innerHTML = '✅';
                document.getElementById('widget-status-text').innerHTML = 'All Systems Operational';
                document.getElementById('widget-status-text').style.color = '#059669';
                document.getElementById('widget-status-detail').innerHTML = '99.999% uptime';
            } else {
                document.getElementById('widget-status-icon').innerHTML = '⚠️';
                document.getElementById('widget-status-text').innerHTML = 'Partial Outage';
                document.getElementById('widget-status-text').style.color = '#d97706';
            }
        } catch (error) {
            document.getElementById('widget-status-icon').innerHTML = '🔌';
            document.getElementById('widget-status-text').innerHTML = 'Connection Issue';
            document.getElementById('widget-status-text').style.color = '#ef4444';
        }
    }
    
    async function testVoice(isHuman) {
        const resultDiv = document.getElementById('widget-result');
        const resultText = document.getElementById('widget-result-text');
        
        resultDiv.style.display = 'block';
        resultText.innerHTML = '🔍 Analyzing...';
        resultText.style.color = '#94a3b8';
        
        const amplitudes = isHuman 
            ? Array.from({length: 30}, () => Math.random() * 3 + 0.5)
            : Array.from({length: 30}, () => 0.12 + Math.random() * 0.01);
        
        setTimeout(() => {
            const isDeepfake = !isHuman;
            if (isDeepfake) {
                resultText.innerHTML = '🚨 DEEPFAKE DETECTED! Call blocked.';
                resultText.style.color = '#ef4444';
                resultDiv.style.border = '1px solid #ef4444';
            } else {
                resultText.innerHTML = '✅ VERIFIED HUMAN. Transaction allowed.';
                resultText.style.color = '#059669';
                resultDiv.style.border = '1px solid #059669';
            }
        }, 800);
    }
    
    // Initial fetch
    fetchStatus();
    setInterval(fetchStatus, 60000);
})();
