public with sharing class GE_FormRendererService {

    @AuraEnabled
    public static FORM_RenderWrapper getRenderWrapperById(Id templateId) {
        FORM_Service formService = new FORM_Service();

        // Get the base template
        FORM_Template queriedTemplate = formService.retrieveFormTemplate(templateId);

        // Create the wrapper which will hold the template and field mapping set.
        FORM_RenderWrapper renderWrapper = wrapTemplate(queriedTemplate);

        return renderWrapper;
    }


    /**
     * This method creates a wrapper which contains the  template selected by name and a field mapping set.
     * If the template is not found, it returns a wrapper for the default template
     * @param String templateName
     * @return  A FORM_RenderWrapper containing the default template JSON.
     */
    public static FORM_RenderWrapper getRenderWrapper(String templateName) {
        FORM_Service formService = new FORM_Service();

        FORM_Template template = formService.retrieveFormTemplate(templateName);

        FORM_RenderWrapper renderWrapper = wrapTemplate(template);

        return renderWrapper;
    }

    /**
     * This method creates a wrapper which contains the default SGE template and a field mapping set.
     *
     * @return  A FORM_RenderWrapper containing the default template JSON.
     */
    public static FORM_RenderWrapper getDefaultSGERenderWrapper() {
        FORM_Service formService = new FORM_Service();

        FORM_Template defaultTemplate = formService.retrieveDefaultSGEFormTemplate();

        FORM_RenderWrapper renderWrapper = wrapTemplate(defaultTemplate);

        return renderWrapper;
    }

    /**
     * This method creates a wrapper which contains the default BGE template and a field mapping set.
     *
     * @return  A FORM_RenderWrapper containing the default template JSON.
     */
    public static FORM_RenderWrapper getDefaultBGERenderWrapper() {
        FORM_Service formService = new FORM_Service();

        FORM_Template defaultTemplate = formService.retrieveDefaultBGEFormTemplate();

        FORM_RenderWrapper renderWrapper = wrapTemplate(defaultTemplate);


        return renderWrapper;
    }

    /**
     * This method builds the wrapper given the template and the field mapping set. 
     *
     * @return  A FORM_RenderWrapper containing the default template JSON.
     */
    private static FORM_RenderWrapper wrapTemplate(FORM_Template template) {
        if (template != null) {
            // Get the mapping service which will retrieve all the mappings
            BDI_MappingServiceAdvanced mappingService = BDI_MappingServiceAdvanced.getInstance();

            updateTemplateWithRequired(template, mappingService.fieldMappingSet);

            // Create the wrapper which will hold the template and field mapping set.
            FORM_RenderWrapper renderWrapper = new FORM_RenderWrapper(template, mappingService.fieldMappingSet);

            return renderWrapper;
        } else {
            return null;
        }
    }

    /*******************************************************************************************************
    * @description Takes the template and field mappings and updates the template so that the required fields are set
    * as required. 
    * @param template - The deserailized template that is stored. 
    * @param fieldMappingSet The field mapping set which determines what DI field is mapped to what target field. 
    */
    private static void updateTemplateWithRequired(FORM_Template template, BDI_FieldMappingSet fieldMappingSet) {
        List<FORM_Section> sectionList = template.layout.sections;

        for (FORM_Section section : sectionList) {
    
            // Go through all the elements
            for (FORM_Element element : section.elements) {
                if (!element.dataImportFieldMappingDevNames.isEmpty()) {
                    
                    if (fieldMappingSet.fieldMappingByDevName.containsKey(element.dataImportFieldMappingDevNames[0])) {
                        BDI_FieldMapping fieldMapping = fieldMappingSet.fieldMappingByDevName.get(element.dataImportFieldMappingDevNames[0]);

                        // Update the element's required by doing an OR between the element's required, DI source field, target field
                        // Update the element's required to make sure we are respecting the source/target/template builder's required
                        // with the most up to date information. 
                        element.required = element.required || fieldMapping.Source_Field_Required || fieldMapping.Target_Field_Required;
                    }
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Takes a Data Import record from the Gift Entry form and saves it to the database.
    * @param diRecord - The DataImport__c record, as filled in by the user.
    * @return The Id of the new Opportunity record, created from the Data Import
    */
    @AuraEnabled
    public static Id saveAndProcessSingleGift(DataImport__c diRecord) {
        // Save the Data Import record to the Database
        diRecord = saveDataImport(diRecord);

        // Run the BDI process on this new Data Import
        runGiftProcess(diRecord, false);

        // Get the ID of the created Opportunity so we can return it
        Id oppId = getOpportunityIdFromImport(diRecord.Id);

        return oppId;

    }

    /*******************************************************************************************************
    * @description Takes a Data Import record and saves it to the database.
    * @param diRecord - The DataImport__c record, as filled in by the user.
    * @return The DataImport__c record that was saved
    */
    private static DataImport__c saveDataImport(DataImport__c diRecord) {
        try {
            insert diRecord;
            return diRecord;
        } catch(Exception e) {
            throw returnAuraException(e.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Run the DataImport process on a single gift
    * @param @param diRecord DataImport record to be processed
    * @param isDryRun Boolean to set if the process should only return import results and not process
    * @return void
    */
    public static void runGiftProcess(DataImport__c diRecord, Boolean isDryRun) {
        Boolean updateGift = false;
        Id diRecordId = diRecord.Id;

        Data_Import_Settings__c diSettings = getGiftEntrySettings(updateGift);

        List<DataImport__c> listDI = new List<DataImport__c>{diRecord};

        BDI_DataImport_API.processDataImportRecords(diSettings, listDI, isDryRun);
    }

    /*******************************************************************************************************
    * @description Return the imported Opportunity (Donation) from a DataImport process
    * @param diObjId Id of DataImport object that created or matching this Opportunity
    * @return Id of the Opportunity
    */
    private static String getOpportunityIdFromImport(Id diRecordId) {
        try {
            DataImport__c di = [
                    SELECT DonationImported__c,
                            FailureInformation__c
                    FROM DataImport__c
                    WHERE Id = :diRecordId
            ];
            if(di.FailureInformation__c != null) {
                throw returnAuraException(di.FailureInformation__c);
            }
            return di.DonationImported__c;
        } catch(Exception e) {
            throw returnAuraException(e.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Set DataImport Settings that are important to Gift Entry matching
    * @return Data_Import_Settings__c diSettings object used to process gifts
    */
    private static Data_Import_Settings__c getGiftEntrySettings(Boolean updateGift) {
        Data_Import_Settings__c diSettings = Data_Import_Settings__c.getOrgDefaults();
        // If we are updating an existing gift, set the matching logic accordingly
        diSettings.Donation_Matching_Behavior__c = 
            updateGift ? BDI_DataImport_API.ExactMatchOrCreate : BDI_DataImport_API.DoNotMatch;
        return diSettings;
    }

    private static AuraHandledException returnAuraException(String errorMsg) {
        AuraHandledException ex = new AuraHandledException(errorMsg);
        ex.setMessage(errorMsg);
        return ex;
    }

}