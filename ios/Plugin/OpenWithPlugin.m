#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(OpenWithPlugin, "OpenWith",
    CAP_PLUGIN_METHOD(addHandler, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(init, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setVerbosity, CAPPluginReturnPromise);
) 