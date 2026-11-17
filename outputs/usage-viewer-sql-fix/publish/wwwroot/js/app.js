// SNOMED CT Static Blazor Application
// Additional JavaScript functionality can be added here

// Global error handling
window.addEventListener('error', function(e) {
    console.error('Global error caught:', e.error);
    console.error('Error details:', {
        message: e.message,
        filename: e.filename,
        lineno: e.lineno,
        colno: e.colno,
        error: e.error
    });
    
    // Update the error message in the UI
    const errorMessageEl = document.getElementById('blazor-error-message');
    if (errorMessageEl) {
        errorMessageEl.textContent = `Error: ${e.message} (Check console for details)`;
    }
});

// Add unhandled promise rejection handler
window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
    
    const errorMessageEl = document.getElementById('blazor-error-message');
    if (errorMessageEl) {
        errorMessageEl.textContent = `Promise rejection: ${e.reason} (Check console for details)`;
    }
});

// Enhanced Bootstrap modal handling
window.blazorHelpers = {
    // Function to scroll to top of page
    scrollToTop: function() {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    },
    
    // Function to copy text to clipboard
    copyToClipboard: function(text) {
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(text);
        } else {
            // Fallback for older browsers
            const textarea = document.createElement('textarea');
            textarea.value = text;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
            return Promise.resolve();
        }
    },
    
    // Function to show browser notification (if permitted)
    showNotification: function(title, body, icon = '/favicon.png') {
        if ('Notification' in window) {
            if (Notification.permission === 'granted') {
                new Notification(title, { body, icon });
            } else if (Notification.permission !== 'denied') {
                Notification.requestPermission().then(permission => {
                    if (permission === 'granted') {
                        new Notification(title, { body, icon });
                    }
                });
            }
        }
    },
    
    // Function to focus element by ID
    focusElement: function(elementId) {
        const element = document.getElementById(elementId);
        if (element) {
            element.focus();
        }
    }
};

// Function to download file (for CSV export)
window.downloadFile = function(filename, content, contentType) {
    const blob = new Blob([content], { type: contentType });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
};

// Initialize application
document.addEventListener('DOMContentLoaded', function() {
    // Add any initialization code here
    console.log('SNOMED CT Blazor App loaded successfully');
    
    // Add keyboard shortcuts
    document.addEventListener('keydown', function(e) {
        // Ctrl+K or Cmd+K to focus search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            const searchInputs = document.querySelectorAll('input[type="text"]');
            if (searchInputs.length > 0) {
                searchInputs[0].focus();
            }
        }
        
        // Ctrl+/ or Cmd+/ to show keyboard shortcuts help
        if ((e.ctrlKey || e.metaKey) && e.key === '/') {
            e.preventDefault();
            showKeyboardShortcuts();
        }
    });
});

// Function to show keyboard shortcuts help
function showKeyboardShortcuts() {
    const shortcuts = [
        'Ctrl/Cmd + K: Focus search input',
        'Ctrl/Cmd + /: Show this help',
        'Enter: Submit search form',
        'Escape: Close modals'
    ];
    
    alert('Keyboard Shortcuts:\n\n' + shortcuts.join('\n'));
}
