#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(OpenWithPlugin, "OpenWith",
    CAP_PLUGIN_METHOD(init, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(exit, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setVerbosity, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getVerbosity, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(addHandler, CAPPluginReturnCallback);
    CAP_PLUGIN_METHOD(load, CAPPluginReturnPromise);
) 